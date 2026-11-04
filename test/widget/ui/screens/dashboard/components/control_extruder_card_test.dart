/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_extruder.dart';
import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/dto/server/klipper_system_info.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klipper_system_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_dialog.dart';
import 'package:mobileraker/ui/components/dialog/filament_operation_dialog.dart';
import 'package:mobileraker/ui/screens/dashboard/components/control_extruder_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;
  late FakeDialogService dialogs;

  ConfigExtruder extruderConfig(String name) => ConfigExtruder(
    name: name,
    nozzleDiameter: 0.4,
    maxExtrudeOnlyDistance: 100,
    minTemp: 0,
    minExtrudeTemp: 170,
    maxTemp: 280,
    filamentDiameter: 1.75,
    maxExtrudeOnlyVelocity: 30,
    maxExtrudeOnlyAccel: 1000,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    double temperature = 215,
    int extruderCount = 1,
    PrintState state = PrintState.standby,
    KlipperState klippy = KlipperState.ready,
    DialogResponse? dialogResponse,
  }) async {
    rpc = FakeJsonRpcClient();
    dialogs = FakeDialogService(response: dialogResponse);
    final names = [for (var i = 0; i < extruderCount; i++) i == 0 ? 'extruder' : 'extruder$i'];
    await tester.pumpApp(
      SingleChildScrollView(child: ControlExtruderCard(machineUUID: machine.uuid)),
      device: TestDevice.tablet,
      overrides: [
        ...uiServiceOverrides(dialogs: dialogs),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: Fixtures.printer(state: state).copyWith(
            extruders: [for (var i = 0; i < extruderCount; i++) Extruder(num: i, temperature: temperature)],
            configFile: ConfigFile()..extruders = {for (final n in names) n: extruderConfig(n)},
          ),
        ),
        machineSettingsProvider(machine.uuid).overrideWithValue(AsyncData(MachineSettings())),
        klippySystemInfoProvider(machine.uuid).overrideWithBuild((_, _) => KlipperSystemInfo()),
      ],
    );
    await tester.pumpAndSettle();
  }

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  ButtonStyleButton button(WidgetTester tester, String label) => tester.widget<ButtonStyleButton>(
    find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()),
  );

  double coldWarningOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: find.byIcon(Icons.severe_cold), matching: find.byType(AnimatedOpacity)),
      )
      .opacity;

  testWidgets('a cold extruder shows the warning and can not extrude', (tester) async {
    await pumpCard(tester, temperature: 120);

    expect(find.text('Extruder'), findsOneWidget);
    expect(coldWarningOpacity(tester), 1);
    expect(button(tester, 'Extrude').onPressed, isNull);
    expect(button(tester, 'Retract').onPressed, isNull);
    await tester.unmountApp();
  });

  testWidgets('a hot extruder extrudes and retracts by the selected step', (tester) async {
    await pumpCard(tester);
    expect(coldWarningOpacity(tester), 0);

    await tester.tap(find.text('Extrude'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retract'));
    await tester.pumpAndSettle();

    expect(scripts(), ['M83\nG1 E1.0 F300.0', 'M83\nG1 E-1.0 F300.0']);
    await tester.unmountApp();
  });

  testWidgets('a selected step size is used and remembered per machine', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extrude'));
    await tester.pumpAndSettle();

    expect(scripts(), ['M83\nG1 E25.0 F300.0']);
    expect(testSettingsBox.get(CompositeKey.keyWithString(UtilityKeys.extruderStepIndex, machine.uuid).key), 2);
    await tester.unmountApp();
  });

  testWidgets('the feed rate dialog changes the extrusion speed', (tester) async {
    await pumpCard(tester, dialogResponse: DialogResponse.confirmed(10));

    await tester.tap(find.byIcon(Icons.speed));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extrude'));
    await tester.pumpAndSettle();

    final args = dialogs.requests.single.data as NumberEditDialogArguments;
    expect(args.current, 5);
    expect(args.max, 30, reason: 'max_extrude_only_velocity');
    expect(scripts(), ['M83\nG1 E1.0 F600.0']);
    await tester.unmountApp();
  });

  testWidgets('load and unload open the filament operation for the active extruder', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('Load'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unload'));
    await tester.pumpAndSettle();

    expect(dialogs.requests.map((r) => r.type), [DialogType.filamentOperation, DialogType.filamentOperation]);
    final args = [for (final r in dialogs.requests) r.data as FilamentOperationDialogArgs];
    expect(args.map((a) => (a.isLoad, a.extruder)), [(true, 'extruder'), (false, 'extruder')]);
    await tester.unmountApp();
  });

  testWidgets('with several extruders the dropdown activates another one', (tester) async {
    await pumpCard(tester, extruderCount: 2);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extruder 1').last);
    await tester.pump();

    expect(scripts(), ['ACTIVATE_EXTRUDER EXTRUDER=extruder1']);
    await tester.unmountApp();
  });

  testWidgets('is hidden while printing', (tester) async {
    await pumpCard(tester, state: PrintState.printing);

    expect(find.text('Extrude'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('remembers that the machine has an extruder', (tester) async {
    await pumpCard(tester);

    expect(testSettingsBox.get(CompositeKey.keyWithString(UiKeys.hadExtruder, machine.uuid).key), isTrue);
    await tester.unmountApp();
  });

  testWidgets('nothing can be moved while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    expect(button(tester, 'Extrude').onPressed, isNull);
    expect(button(tester, 'Load').onPressed, isNull);
    expect(button(tester, 'Unload').onPressed, isNull);
    await tester.unmountApp();
  });
}
