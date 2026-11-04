/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/ui/components/slider_or_text_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/screens/dashboard/components/limits_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

  Future<void> pumpCard(WidgetTester tester, {KlipperState klippy = KlipperState.ready}) async {
    rpc = FakeJsonRpcClient();
    final printer = Fixtures.printer();
    await tester.pumpApp(
      SingleChildScrollView(child: LimitsCard(machineUUID: machine.uuid)),
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: printer.copyWith(
            toolhead: printer.toolhead.copyWith(
              maxVelocity: 250,
              maxAccel: 4000,
              squareCornerVelocity: 5,
              maxAccelToDecel: 2000,
            ),
          ),
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

  testWidgets('shows the toolhead limits', (tester) async {
    await pumpCard(tester);

    expect(find.text('Limits'), findsOneWidget);
    expect(find.text('Velocity: 250 mm/s'), findsOneWidget);
    expect(find.text('Acceleration: 4000 mm/s²'), findsOneWidget);
    expect(find.text('Square Corner Velocity: 5 mm/s'), findsOneWidget);
    expect(find.text('Accel to Decel: 2000 mm/s²'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('is locked until the lock is tapped', (tester) async {
    await pumpCard(tester);
    expect(inputs(tester), hasLength(4));
    expect(inputs(tester).every((i) => i.onChange == null), isTrue);

    await unlock(tester);

    expect(inputs(tester).every((i) => i.onChange != null), isTrue);
    await tester.unmountApp();
  });

  for (final (index, entered, gcode) in [
    (0, '300', 'SET_VELOCITY_LIMIT VELOCITY=300'),
    (1, '5000', 'SET_VELOCITY_LIMIT ACCEL=5000'),
    (2, '6.5', 'SET_VELOCITY_LIMIT SQUARE_CORNER_VELOCITY=6.5'),
    (3, '2500', 'SET_VELOCITY_LIMIT ACCEL_TO_DECEL=2500'),
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
