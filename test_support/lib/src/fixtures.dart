/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/print_stats.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/machine/printer_builder.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/dto/server/moonraker_version.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/temperature_store_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;

import 'fake_json_rpc_client.dart';

/// Test data. Builders take the fields tests usually care about; everything else has a plain default.
abstract final class Fixtures {
  static Machine machine({String uuid = 'm1', String name = 'Voron'}) =>
      Machine(name: name, httpUri: Uri.parse('http://${name.toLowerCase().replaceAll(' ', '-')}.local'), uuid: uuid);

  /// Klipper connected and ready, with the given Moonraker [components] (e.g. `spoolman`, `timelapse`).
  static KlipperInstance klipper({
    KlipperState state = KlipperState.ready,
    List<String> components = const [],
    String? stateMessage,
  }) => KlipperInstance(
    klippyConnected: state != KlipperState.disconnected,
    klippyState: state,
    components: components,
    moonrakerVersion: MoonrakerVersion.fallback(),
    klippyStateMessage: stateMessage,
  );

  /// A minimal printer (toolhead, gcode move, print stats, config) in [state], optionally printing [filename].
  /// Customize further via [PrinterBuilder] / `copyWith` on the result.
  static Printer printer({PrintState state = PrintState.standby, String filename = ''}) =>
      (PrinterBuilder.preview()..print = PrintStats(state: state, filename: filename)).build();

  static Folder folder(String name, {String parentPath = 'gcodes'}) =>
      Folder(parentPath: parentPath, modified: 1700000000, name: name, size: 0);

  static GCodeFile gcode(
    String name, {
    String parentPath = 'gcodes',
    int size = 1024 * 1024,
    double? estimatedTime = 3600,
    double modified = 1700000000,
  }) => GCodeFile(name: name, parentPath: parentPath, modified: modified, size: size, estimatedTime: estimatedTime);
}

/// Reports a fixed [KlipperInstance] instead of querying Moonraker.
class FakeKlipper extends Klipper {
  FakeKlipper(this.instance);

  final KlipperInstance instance;

  @override
  Future<KlipperInstance> build(String machineUUID) async => instance;
}

/// Reports a fixed [Printer] instead of querying Klipper.
class FakePrinter extends PrinterNotifier {
  FakePrinter(this.printer);

  final Printer printer;

  @override
  Future<Printer> build(String machineUUID) async => printer;
}

/// Temperature history without a websocket: always empty.
class NoTemperatureHistory extends TemperatureStores {
  @override
  Future<TemperatureStore> build(String machineUUID) async => {};
}

/// Overrides for a machine whose websocket is in [clientState] (connected by default, with [client], a
/// [FakeJsonRpcClient] by default) and whose Klipper is [klipper] (ready, without components by default) with
/// [printer] (standby by default).
///
/// With [selected] (default) it is also the selected machine; pass `false` for all but one machine of multi-machine
/// tests. [klipperNotifier] / [printerNotifier] replace the fixed [klipper] / [printer] with a custom notifier (e.g. one
/// the test changes or that fails).
List<Override> connectedMachineOverrides(
  Machine machine, {
  FakeJsonRpcClient? client,
  KlipperInstance? klipper,
  Printer? printer,
  Klipper Function()? klipperNotifier,
  PrinterNotifier Function()? printerNotifier,
  bool selected = true,
  ClientState clientState = ClientState.connected,
}) {
  final rpc = client ?? FakeJsonRpcClient();
  return [
    klipperProvider(machine.uuid).overrideWith(klipperNotifier ?? () => FakeKlipper(klipper ?? Fixtures.klipper())),
    printerProvider(machine.uuid).overrideWith(printerNotifier ?? () => FakePrinter(printer ?? Fixtures.printer())),
    if (selected) selectedMachineProvider.overrideWithValue(AsyncData(machine)),
    machineProvider(machine.uuid).overrideWithValue(AsyncData(machine)),
    jrpcClientProvider(machine.uuid).overrideWithValue(rpc),
    jrpcClientStateProvider(machine.uuid).overrideWithValue(AsyncData(clientState)),
    jrpcClientTypeProvider(machine.uuid).overrideWithValue(rpc.clientType),
  ];
}

/// Remote config without Firebase: the given values, otherwise 0 / false / ''.
List<Override> remoteConfigOverrides({
  Map<String, int> ints = const {},
  Map<String, bool> bools = const {},
  Map<String, String> strings = const {},
}) => [
  remoteConfigIntProvider.overrideWith((ref, key) => ints[key] ?? 0),
  remoteConfigBoolProvider.overrideWith((ref, key) => bools[key] ?? false),
  remoteConfigStringProvider.overrideWith((ref, key) => strings[key] ?? ''),
];

/// Records snackbars instead of showing them.
class FakeSnackBarService extends Fake implements SnackBarService {
  final List<SnackBarConfig> shown = [];

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(SnackBarConfig config) {
    shown.add(config);
    return null;
  }

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showForMachine(
    String machineUUID,
    SnackBarConfig config,
  ) => show(config);
}

/// Records dialog requests instead of showing them; answers each with [response] (null, like a dismissed dialog, by
/// default).
class FakeDialogService extends Fake implements DialogService {
  FakeDialogService({this.response});

  DialogResponse? response;
  final List<DialogRequest> requests = [];

  /// Confirm dialogs, recorded by title.
  final List<String?> confirms = [];

  @override
  bool get isDialogOpen => false;

  @override
  Future<DialogResponse?> show(DialogRequest request) async {
    requests.add(request);
    return response;
  }

  @override
  Future<DialogResponse?> showConfirm({
    String? title,
    String? body,
    String? actionLabel,
    String? dismissLabel,
    Color? actionForegroundColor,
    Color? actionBackgroundColor,
  }) async {
    confirms.add(title);
    return response;
  }

  @override
  Future<DialogResponse?> showDangerConfirm({
    String? title,
    String? body,
    String? actionLabel,
    String? dismissLabel,
  }) async {
    confirms.add(title);
    return response;
  }
}

/// Records bottom sheet configs instead of showing them; answers each with [result] (dismissed by default).
class FakeBottomSheetService extends Fake implements BottomSheetService {
  FakeBottomSheetService({BottomSheetResult? result}) : result = result ?? BottomSheetResult.dismissed();

  BottomSheetResult result;
  final List<BottomSheetConfig> shown = [];

  @override
  Future<BottomSheetResult> show(BottomSheetConfig config) async {
    shown.add(config);
    return result;
  }
}

/// The UI services the app provides in main() (snackbar, dialog and bottom sheet service).
List<Override> uiServiceOverrides({
  FakeSnackBarService? snackBars,
  FakeDialogService? dialogs,
  FakeBottomSheetService? bottomSheets,
}) => [
  snackBarServiceProvider.overrideWithValue(snackBars ?? FakeSnackBarService()),
  dialogServiceProvider.overrideWithValue(dialogs ?? FakeDialogService()),
  bottomSheetServiceProvider.overrideWithValue(bottomSheets ?? FakeBottomSheetService()),
];
