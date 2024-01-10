/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/machine_settings.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'dashboard_controller.g.dart';

@riverpod
Stream<PrinterKlippySettingsMachineWrapper> machinePrinterKlippySettings(
  MachinePrinterKlippySettingsRef ref,
) async* {
  var selMachine = await ref.watch(selectedMachineProvider.future);
  if (selMachine == null) {
    return;
  }

  var klippy = ref.watchAsSubject(klipperProvider(selMachine.uuid));
  var printer = ref.watchAsSubject(printerProvider(selMachine.uuid));
  var machineSettings = ref.watchAsSubject(
    selectedMachineSettingsProvider,
    // THe skip is required because I want to use the cached value (So if the selectedMachineSettingsProvider goes into loading I still want to use the last valid value)
    // For the other two I want that this provider goes into the loading state, if I change them!
    skipLoadingOnReload: true,
  );
  var clientType = ref.watch(jrpcClientTypeProvider(selMachine.uuid));

  yield* Rx.combineLatest3(
    printer,
    klippy,
    machineSettings,
    (Printer a, KlipperInstance b, MachineSettings c) => PrinterKlippySettingsMachineWrapper(
      printerData: a,
      klippyData: b,
      settings: c,
      machine: selMachine,
      clientType: clientType,
    ),
  );
}

class PrinterKlippySettingsMachineWrapper {
  const PrinterKlippySettingsMachineWrapper({
    required this.printerData,
    required this.klippyData,
    required this.settings,
    required this.machine,
    required this.clientType,
  });

  final Printer printerData;
  final KlipperInstance klippyData;
  final MachineSettings settings;
  final Machine machine;
  final ClientType clientType;
}
