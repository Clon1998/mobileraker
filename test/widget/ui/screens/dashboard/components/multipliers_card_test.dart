/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/gcode_move.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/ui/components/slider_or_text_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/screens/dashboard/components/multipliers_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

  Future<void> pumpCard(WidgetTester tester, {KlipperState klippy = KlipperState.ready}) async {
    rpc = FakeJsonRpcClient();
    await tester.pumpApp(
      SingleChildScrollView(child: MultipliersCard(machineUUID: machine.uuid)),
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: Fixtures.printer().copyWith(gCodeMove: const GCodeMove(speedFactor: 1, extrudeFactor: 0.95)),
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

  /// The G-code scripts sent to the printer.
  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  testWidgets('shows speed and flow of the printer', (tester) async {
    await pumpCard(tester);

    expect(find.text('Speed: 100%'), findsOneWidget);
    expect(find.text('Flow: 95%'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('no pressure advance/smooth time without an extruder', (tester) async {
    await pumpCard(tester);

    expect(inputs(tester), hasLength(2));
    await tester.unmountApp();
  });

  testWidgets('is locked until the lock is tapped', (tester) async {
    await pumpCard(tester);
    expect(inputs(tester).every((i) => i.onChange == null), isTrue);

    await unlock(tester);

    expect(inputs(tester).every((i) => i.onChange != null), isTrue);
    await tester.unmountApp();
  });

  testWidgets('entering a speed sends M220', (tester) async {
    await pumpCard(tester);
    await unlock(tester);

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '110');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(scripts(), ['M220 S110']);
    await tester.unmountApp();
  });

  testWidgets('releasing the flow slider sends M221', (tester) async {
    await pumpCard(tester);
    await unlock(tester);

    await tester.drag(find.byType(Slider).last, const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(scripts(), hasLength(1));
    expect(scripts().single, startsWith('M221 S'));
    await tester.unmountApp();
  });

  testWidgets('stays locked while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    final lock = tester.widget<IconButton>(find.byType(IconButton).first);
    expect(lock.onPressed, isNull);
    expect(inputs(tester).every((i) => i.onChange == null), isTrue);
    await tester.unmountApp();
  });
}
