/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/gcode_move.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/printer_axis_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/dashboard/components/z_offset_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

  Future<void> pumpCard(
    WidgetTester tester, {
    PrintState state = PrintState.printing,
    KlipperState klippy = KlipperState.ready,
    bool zHomed = false,
  }) async {
    rpc = FakeJsonRpcClient();
    final printer = Fixtures.printer(state: state);
    await tester.pumpApp(
      SingleChildScrollView(child: ZOffsetCard(machineUUID: machine.uuid)),
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: printer.copyWith(
            gCodeMove: const GCodeMove(homingOrigin: [0, 0, 0.123, 0]),
            toolhead: printer.toolhead.copyWith(homedAxes: zHomed ? {PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z} : {}),
          ),
        ),
        machineSettingsProvider(machine.uuid).overrideWithValue(AsyncData(MachineSettings())),
      ],
    );
    await tester.pumpAndSettle();
  }

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  Future<void> tapIcon(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the z offset and the baby steps while printing', (tester) async {
    await pumpCard(tester);

    expect(find.text('Micro-Step Z-Axis'), findsOneWidget);
    expect(find.text('0.123mm'), findsOneWidget);
    for (final step in ['0.005', '0.01', '0.05', '0.1']) {
      expect(find.text(step), findsOneWidget);
    }
    await tester.unmountApp();
  });

  testWidgets('is hidden while not printing', (tester) async {
    await pumpCard(tester, state: PrintState.standby);

    expect(find.text('Micro-Step Z-Axis'), findsNothing);
    expect(find.byType(Card), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('is shown while not printing with "always show baby stepping"', (tester) async {
    await testSettingsBox.put(AppSettingKeys.alwaysShowBabyStepping.key, true);
    await pumpCard(tester, state: PrintState.standby);

    expect(find.text('Micro-Step Z-Axis'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('up/down step the z offset by the first step without moving when Z is not homed', (tester) async {
    await pumpCard(tester);

    await tapIcon(tester, AntDesign.upsquare);
    await tapIcon(tester, AntDesign.downsquare);

    expect(scripts(), ['SET_GCODE_OFFSET Z_ADJUST=0.005 MOVE=0', 'SET_GCODE_OFFSET Z_ADJUST=-0.005 MOVE=0']);
    await tester.unmountApp();
  });

  testWidgets('moves the toolhead with the offset when Z is homed', (tester) async {
    await pumpCard(tester, zHomed: true);

    await tapIcon(tester, AntDesign.upsquare);

    expect(scripts(), ['SET_GCODE_OFFSET Z_ADJUST=0.005 MOVE=1']);
    await tester.unmountApp();
  });

  testWidgets('a selected step size is used and remembered per machine', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('0.1'));
    await tester.pumpAndSettle();
    await tapIcon(tester, AntDesign.upsquare);

    expect(scripts(), ['SET_GCODE_OFFSET Z_ADJUST=0.1 MOVE=0']);
    expect(testSettingsBox.get(CompositeKey.keyWithString(UtilityKeys.zOffsetStepIndex, machine.uuid).key), 3);
    await tester.unmountApp();
  });

  testWidgets('starts with the remembered step size', (tester) async {
    await testSettingsBox.put(CompositeKey.keyWithString(UtilityKeys.zOffsetStepIndex, machine.uuid).key, 2);
    await pumpCard(tester);

    await tapIcon(tester, AntDesign.upsquare);

    expect(scripts(), ['SET_GCODE_OFFSET Z_ADJUST=0.05 MOVE=0']);
    await tester.unmountApp();
  });

  testWidgets('buttons are disabled while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    await tester.tap(find.byIcon(AntDesign.upsquare), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(scripts(), isEmpty);
    await tester.unmountApp();
  });
}
