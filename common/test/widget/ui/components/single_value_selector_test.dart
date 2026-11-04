/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/components/single_value_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  const steps = ['0.1', '1', '10', '100'];

  testWidgets('shows one segment per value with the selected one marked', (tester) async {
    await tester.pumpApp(SingleValueSelector(values: steps, selectedIndex: 2, onSelected: (_) {}));

    for (final step in steps) {
      expect(find.text(step), findsOneWidget);
    }
    final button = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
    expect(button.selected, {'10'});
  });

  testWidgets('selecting another value reports its index', (tester) async {
    final selected = <int>[];
    await tester.pumpApp(SingleValueSelector(values: steps, selectedIndex: 0, onSelected: selected.add));

    await tester.tap(find.text('100'));
    await tester.pump();

    expect(selected, [3]);
  });

  testWidgets('tapping the selected value reports nothing', (tester) async {
    final selected = <int>[];
    await tester.pumpApp(SingleValueSelector(values: steps, selectedIndex: 1, onSelected: selected.add));

    await tester.tap(find.text('1'));
    await tester.pump();

    expect(selected, isEmpty);
  });

  testWidgets('scrolls horizontally instead of overflowing on a narrow screen', (tester) async {
    await tester.pumpApp(
      SingleValueSelector(values: [for (var i = 0; i < 12; i++) 'Step $i'], onSelected: (_) {}),
      device: TestDevice.sized(320, 600),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
