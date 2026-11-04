/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/components/slider_or_text_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final submitted = <double>[];
  setUp(submitted.clear);

  Widget input({double value = 1, bool enabled = true, bool submitOnChange = false, bool addToMax = false}) =>
      SliderOrTextInput(
        value: value,
        prefixText: 'Speed',
        onChange: enabled ? submitted.add : null,
        submitOnChange: submitOnChange,
        addToMax: addToMax,
      );

  Slider slider(WidgetTester tester) => tester.widget<Slider>(find.byType(Slider));

  Future<void> switchToText(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the prefix and the value as percent', (tester) async {
    await tester.pumpApp(input(value: 1));

    expect(find.text('Speed: 100%'), findsOneWidget);
    expect(slider(tester).value, 1);
  });

  testWidgets('submits once when the slider is released', (tester) async {
    await tester.pumpApp(input(value: 1));

    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(submitted, hasLength(1));
    expect(submitted.single, greaterThan(1));
    expect(find.text('Speed: 100%'), findsNothing);
  });

  testWidgets('with submitOnChange it submits while dragging', (tester) async {
    await tester.pumpApp(input(value: 1, submitOnChange: true));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(Slider)));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(submitted.length, greaterThanOrEqualTo(2));
  });

  testWidgets('the edit button switches to a text field with the current value', (tester) async {
    await tester.pumpApp(input(value: 1));

    await switchToText(tester);

    expect(find.widgetWithText(TextField, '100'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('the edit button focuses the text field', (tester) async {
    await tester.pumpApp(input(value: 1));

    await switchToText(tester);

    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
  });

  testWidgets('submitting the text field sends the typed percentage', (tester) async {
    await tester.pumpApp(input(value: 1));
    await switchToText(tester);

    await tester.enterText(find.byType(TextField), '150');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(submitted, [1.5]);
  });

  testWidgets('an empty text field shows an error and disables the checkmark', (tester) async {
    await tester.pumpApp(input(value: 1));
    await switchToText(tester);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    final check = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.check));
    expect(check.onPressed, isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).decoration!.errorText, isNotNull);
    expect(submitted, isEmpty);
  });

  testWidgets('follows a new value from the parent', (tester) async {
    await tester.pumpApp(input(value: 1));
    await tester.pumpApp(input(value: 0.5));

    expect(find.text('Speed: 50%'), findsOneWidget);
  });

  testWidgets('is read-only without onChange', (tester) async {
    await tester.pumpApp(input(enabled: false));

    expect(slider(tester).onChanged, isNull);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.edit)).onPressed, isNull);
  });

  testWidgets('with addToMax, releasing at the max extends the range', (tester) async {
    await tester.pumpApp(input(value: 2, addToMax: true));
    expect(slider(tester).max, 2);

    // Drag to the very end of the slider.
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();

    expect(slider(tester).max, 3);
  });
}
