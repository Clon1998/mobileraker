/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/firmware_retraction.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/slider_or_text_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/screens/dashboard/components/firmware_retraction_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  final hadFwRetractKey = CompositeKey.keyWithString(UiKeys.hadFirmwareRetraction, machine.uuid).key;
  late FakeJsonRpcClient rpc;

  const retraction = FirmwareRetraction(
    retractLength: 0.7,
    retractSpeed: 15,
    unretractExtraLength: 0.32,
    unretractSpeed: 22,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    FirmwareRetraction? firmwareRetraction = retraction,
    KlipperState klippy = KlipperState.ready,
  }) async {
    rpc = FakeJsonRpcClient();
    await tester.pumpApp(
      SingleChildScrollView(child: FirmwareRetractionCard(machineUUID: machine.uuid)),
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: Fixtures.printer().copyWith(firmwareRetraction: firmwareRetraction),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  Iterable<SliderOrTextInput> inputs(WidgetTester tester) =>
      tester.widgetList<SliderOrTextInput>(find.byType(SliderOrTextInput));

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
  }

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  Future<void> enter(WidgetTester tester, int index, String text) async {
    final input = find.byType(SliderOrTextInput).at(index);
    Finder inInput(Finder f) => find.descendant(of: input, matching: f);
    await tester.ensureVisible(input);
    await tester.tap(inInput(find.byIcon(Icons.edit)));
    await tester.pumpAndSettle();
    await tester.tap(inInput(find.byType(TextField)));
    await tester.enterText(inInput(find.byType(TextField)), text);
    await tester.tap(inInput(find.byIcon(Icons.check)));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the retraction settings of the printer', (tester) async {
    await pumpCard(tester);

    expect(find.text('Firmware Retraction'), findsOneWidget);
    expect(find.text('Retract Length: 0.7 mm'), findsOneWidget);
    expect(find.text('Extra Unretract Length: 0.32 mm'), findsOneWidget);
    expect(find.text('Retract Speed: 15 mm/s'), findsOneWidget);
    expect(find.text('Unretract Speed: 22 mm/s'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('is hidden when the printer has no firmware retraction', (tester) async {
    await pumpCard(tester, firmwareRetraction: null);

    expect(find.byType(Card), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('remembers that the machine has firmware retraction', (tester) async {
    await pumpCard(tester);

    expect(testSettingsBox.get(hadFwRetractKey), isTrue);
    await tester.unmountApp();
  });

  testWidgets('remembers that the machine has no firmware retraction', (tester) async {
    await pumpCard(tester, firmwareRetraction: null);

    expect(testSettingsBox.get(hadFwRetractKey), isFalse);
    await tester.unmountApp();
  });

  testWidgets(
    'is hidden once firmware retraction is removed from a machine that had it',
    (tester) async {
      await testSettingsBox.put(hadFwRetractKey, true);
      await pumpCard(tester, firmwareRetraction: null);

      expect(tester.takeException(), isNull);
      expect(find.byType(Card), findsNothing);
      await tester.unmountApp();
    },
  );

  testWidgets('is locked until the lock is tapped', (tester) async {
    await pumpCard(tester);
    expect(inputs(tester).every((i) => i.onChange == null), isTrue);

    await unlock(tester);

    expect(inputs(tester).every((i) => i.onChange != null), isTrue);
    await tester.unmountApp();
  });

  for (final (index, entered, gcode) in [
    (0, '1.5', 'SET_RETRACTION RETRACT_LENGTH=1.5'),
    (1, '0.1', 'SET_RETRACTION UNRETRACT_EXTRA_LENGTH=0.1'),
    (2, '40', 'SET_RETRACTION RETRACT_SPEED=40.0'),
    (3, '30', 'SET_RETRACTION UNRETRACT_SPEED=30.0'),
  ]) {
    testWidgets('entering input #$index sends $gcode', (tester) async {
      await pumpCard(tester);
      await unlock(tester);

      await enter(tester, index, entered);

      expect(scripts(), [gcode]);
      await tester.unmountApp();
    });
  }

  testWidgets('stays locked while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    expect(tester.widget<IconButton>(find.byType(IconButton).first).onPressed, isNull);
    expect(inputs(tester).every((i) => i.onChange == null), isTrue);
    await tester.unmountApp();
  });
}
