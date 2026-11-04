/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/service/setting_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/components/console/console_card.dart';
import 'package:mobileraker/ui/components/console/console_settings_button.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

  final now = DateTime.now().millisecondsSinceEpoch / 1000;

  Future<void> pumpCard(WidgetTester tester, {KlipperState klippy = KlipperState.ready}) async {
    rpc = FakeJsonRpcClient(
      responses: {
        'server.gcode_store': (_) => {
          'gcode_store': [
            {'message': 'G28', 'type': 'command', 'time': now - 30},
            {'message': '// Homing done', 'type': 'response', 'time': now - 20},
            {'message': 'B:60.0 /60.0 T0:215.0 /215.0', 'type': 'response', 'time': now - 10},
          ],
        },
        'printer.gcode.help': (_) => {
          'FIRMWARE_RESTART': 'Restart firmware, host, and reload config',
          'STATUS': 'Report the printer status',
          'BED_MESH_CALIBRATE': 'Perform Mesh Bed Leveling',
        },
      },
    );
    await tester.pumpApp(
      SingleChildScrollView(child: ConsoleCard(machineUUID: machine.uuid)),
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  /// An entry of the history (commands are also offered as suggestion chips).
  Finder history(String text) => find.widgetWithText(ListTile, text);

  TextField input(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField));

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  testWidgets('shows the cached console history', (tester) async {
    await pumpCard(tester);

    expect(find.text('GCode Console'), findsOneWidget);
    expect(history('G28'), findsOneWidget);
    expect(find.text('// Homing done'), findsOneWidget);
    expect(find.text('B:60.0 /60.0 T0:215.0 /215.0'), findsNothing, reason: 'temperature reports are filtered');
    await tester.unmountApp();
  });

  testWidgets('shows temperature reports when the filter is turned off', (tester) async {
    await testSettingsBox.put(AppSettingKeys.filterTemperatureResponse.key, false);
    await pumpCard(tester);

    expect(find.text('B:60.0 /60.0 T0:215.0 /215.0'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('tapping a command of the history puts it into the input', (tester) async {
    await pumpCard(tester);

    await tester.tap(history('G28'));
    await tester.pumpAndSettle();

    expect(input(tester).controller!.text, 'G28');
    await tester.unmountApp();
  });

  testWidgets('sending a command runs it, clears the input and adds it to the history', (tester) async {
    await pumpCard(tester);
    expect(find.byType(ConsoleSettingsButton), findsOneWidget, reason: 'settings instead of send while empty');

    await tester.enterText(find.byType(TextField), 'M115');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pumpAndSettle();

    expect(scripts(), ['M115']);
    expect(input(tester).controller!.text, isEmpty);
    expect(history('M115'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('the keyboard "done" action sends the command', (tester) async {
    await pumpCard(tester);

    await tester.enterText(find.byType(TextField), 'STATUS');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(scripts(), ['STATUS']);
    await tester.unmountApp();
  });

  testWidgets('suggests commands matching the input, a tap fills it in', (tester) async {
    await pumpCard(tester);

    await tester.enterText(find.byType(TextField), 'firm');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final firstChip = tester.widget<ActionChip>(find.byType(ActionChip).first);
    expect((firstChip.label as Text).data, 'FIRMWARE_RESTART');

    await tester.tap(find.byType(ActionChip).first);
    await tester.pumpAndSettle();

    expect(input(tester).controller!.text, 'FIRMWARE_RESTART');
    await tester.unmountApp();
  });

  testWidgets('without input it suggests recent commands first', (tester) async {
    await pumpCard(tester);

    final firstChip = tester.widget<ActionChip>(find.byType(ActionChip).first);
    expect((firstChip.label as Text).data, 'G28');
    await tester.unmountApp();
  });

  testWidgets('the input is disabled while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    expect(input(tester).enabled, isFalse);
    expect(input(tester).decoration!.hintText, 'Fetching console entries…');
    await tester.unmountApp();
  });
}
