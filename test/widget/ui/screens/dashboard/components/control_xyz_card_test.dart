/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

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
import 'package:mobileraker/ui/screens/dashboard/components/control_xyz_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

  const allHomed = {PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z};

  Future<void> pumpCard(
    WidgetTester tester, {
    Set<PrinterAxis> homed = allHomed,
    PrintState state = PrintState.standby,
    KlipperState klippy = KlipperState.ready,
    MachineSettings? settings,
  }) async {
    rpc = FakeJsonRpcClient();
    final printer = Fixtures.printer(state: state);
    await tester.pumpApp(
      SingleChildScrollView(child: ControlXYZCard(machineUUID: machine.uuid)),
      device: TestDevice.tablet,
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: printer.copyWith(toolhead: printer.toolhead.copyWith(homedAxes: homed)),
        ),
        machineSettingsProvider(
          machine.uuid,
        ).overrideWithValue(AsyncData(settings ?? MachineSettings(moveSteps: [1, 10, 25, 50]))),
      ],
    );
    await tester.pumpAndSettle();
  }

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  Finder moveButton(IconData icon) => find.ancestor(of: find.byIcon(icon), matching: find.byType(ElevatedButton));

  bool enabled(WidgetTester tester, IconData icon) =>
      tester.widgetList<ElevatedButton>(moveButton(icon)).every((b) => b.onPressed != null);

  Future<void> tapIcon(WidgetTester tester, IconData icon, {int index = 0}) async {
    await tester.tap(find.byIcon(icon).at(index));
    await tester.pumpAndSettle();
  }

  // The Z buttons reuse the up/down icons: index 0 is XY, 1 is Z.
  const up = AntDesign.upsquare, down = AntDesign.downsquare;
  const left = AntDesign.leftsquare, right = AntDesign.rightsquare;

  testWidgets('shows the move controls and the position', (tester) async {
    await pumpCard(tester);

    expect(find.text('Move Axis'), findsOneWidget);
    expect(find.byIcon(up), findsNWidgets(2));
    expect(find.byIcon(Icons.home), findsWidgets);
    expect(find.text('ALL'), findsOneWidget);
    for (final step in ['1', '10', '25', '50']) {
      expect(find.text(step), findsOneWidget, reason: step);
    }
    await tester.unmountApp();
  });

  testWidgets('is hidden while printing', (tester) async {
    await pumpCard(tester, state: PrintState.printing);

    expect(find.text('Move Axis'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('moves are disabled until the axis is homed, homing is not', (tester) async {
    await pumpCard(tester, homed: {PrinterAxis.Z});

    expect(enabled(tester, left), isFalse);
    expect(enabled(tester, right), isFalse);
    expect(tester.widgetList<ElevatedButton>(moveButton(up)).map((b) => b.onPressed != null), [false, true]);
    expect(find.byTooltip('Home X and Y axes'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.descendant(of: find.byTooltip('Home X and Y axes'), matching: find.byType(ElevatedButton)),
          )
          .onPressed,
      isNotNull,
    );
    await tester.unmountApp();
  });

  testWidgets('jogging moves relative by the selected step with the configured speeds', (tester) async {
    await pumpCard(tester);

    await tapIcon(tester, right);
    await tapIcon(tester, down);
    await tapIcon(tester, up, index: 1);

    expect(scripts(), ['G91\nG1 X+1.00 F3000.0\nG90', 'G91\nG1 Y-1.00 F3000.0\nG90', 'G91\nG1 Z+1.00 F1800.0\nG90']);
    await tester.unmountApp();
  });

  testWidgets('inverted axes move the other way', (tester) async {
    await pumpCard(
      tester,
      settings: MachineSettings(moveSteps: [1, 10], inverts: [true, false, true]),
    );

    await tapIcon(tester, right);
    await tapIcon(tester, up, index: 1);

    expect(scripts(), ['G91\nG1 X-1.00 F3000.0\nG90', 'G91\nG1 Z-1.00 F1800.0\nG90']);
    await tester.unmountApp();
  });

  testWidgets('a selected step size is used and remembered per machine', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    await tapIcon(tester, left);

    expect(scripts(), ['G91\nG1 X-25.00 F3000.0\nG90']);
    expect(testSettingsBox.get(CompositeKey.keyWithString(UtilityKeys.moveStepIndex, machine.uuid).key), 2);
    await tester.unmountApp();
  });

  testWidgets('home buttons home XY, Z or all axes', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.descendant(of: find.byTooltip('Home X and Y axes'), matching: find.byType(ElevatedButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byTooltip('Home Z axis'), matching: find.byType(ElevatedButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALL'));
    await tester.pumpAndSettle();

    expect(scripts(), ['G28 X Y', 'G28 Z', 'G28']);
    await tester.unmountApp();
  });

  testWidgets('nothing works while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    expect(enabled(tester, left) || enabled(tester, right), isFalse);
    expect(tester.widgetList<ElevatedButton>(find.byType(ElevatedButton)).every((b) => b.onPressed == null), isTrue);
    await tester.unmountApp();
  });
}
