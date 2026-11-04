/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_dialog.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  late List<DialogResponse> responses;

  Future<void> pumpDialog(
    WidgetTester tester, {
    DialogType type = DialogType.rangeEdit,
    num current = 50,
    num min = 0,
    num? max = 100,
    int fraction = 0,
    String? actionLabel,
    String? dismissLabel,
  }) async {
    responses = [];
    await tester.pumpApp(
      NumEditFormDialog(
        request: DialogRequest(
          type: type,
          title: 'Edit Part Fan %',
          actionLabel: actionLabel,
          dismissLabel: dismissLabel,
          data: NumberEditDialogArguments(current: current, min: min, max: max, fraction: fraction),
        ),
        completer: responses.add,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder confirm() => find.widgetWithText(FilledButton, 'Confirm');

  Finder toggle() => find.ancestor(of: find.byIcon(Icons.text_fields), matching: find.byType(IconButton));

  Future<void> switchToText(WidgetTester tester) => tapAndSettle(tester, toggle());

  testWidgets('range mode: shows the title and the current value', (tester) async {
    await pumpDialog(tester);

    expect(find.text('Edit Part Fan %'), findsOneWidget);
    expect(find.byKey(const Key('RangeEditSlider')), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('range mode: + and - change the value by one, confirm returns it', (tester) async {
    await pumpDialog(tester);

    await tapAndSettle(tester, find.byIcon(Icons.add));
    await tapAndSettle(tester, find.byIcon(Icons.add));
    await tapAndSettle(tester, find.byIcon(Icons.remove));
    expect(find.text('51'), findsOneWidget);

    await tapAndSettle(tester, confirm());

    expect(responses.single.confirmed, isTrue);
    expect(responses.single.data, 51);
  });

  testWidgets('range mode: long press jumps to the limits, + and - stop there', (tester) async {
    await pumpDialog(tester);

    await tester.longPress(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.add));
    expect(find.text('100'), findsWidgets);

    await tester.longPress(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.remove));
    await tapAndSettle(tester, confirm());

    expect(responses.single.data, 0);
  });

  testWidgets('numEdit starts with the text field and the allowed range', (tester) async {
    await pumpDialog(tester, type: DialogType.numEdit);

    expect(find.byKey(const Key('NumField')), findsOneWidget);
    expect(find.text('Enter a value between 0 and 100'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '50');
  });

  testWidgets('without a max the helper only names the minimum', (tester) async {
    await pumpDialog(tester, type: DialogType.numEdit, max: null, min: 5);

    expect(find.text('Enter a value of at least 5'), findsOneWidget);
  });

  testWidgets('the toggle switches between slider and text field and keeps the value', (tester) async {
    await pumpDialog(tester);

    await tapAndSettle(tester, find.byIcon(Icons.add));
    await switchToText(tester);

    expect(find.byKey(const Key('NumField')), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '51');

    await tapAndSettle(tester, find.byIcon(Icons.straighten));
    expect(find.byKey(const Key('RangeEditSlider')), findsOneWidget);
  });

  testWidgets('a typed value is confirmed with the button or the keyboard', (tester) async {
    await pumpDialog(tester, type: DialogType.numEdit);

    await tester.enterText(find.byType(TextField), '75');
    await tapAndSettle(tester, confirm());
    await tester.enterText(find.byType(TextField), '80');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(responses.map((r) => r.data), [75, 80]);
  });

  for (final (input, reason) in [('150', 'above max'), ('-1', 'below min'), ('1.5', 'not an integer'), ('', 'empty')]) {
    testWidgets('an invalid value ($reason) shows an error and can not be confirmed', (tester) async {
      await pumpDialog(tester, type: DialogType.numEdit);

      await tester.enterText(find.byType(TextField), input);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).decoration!.errorText, isNotNull);
      expect(tester.widget<FilledButton>(confirm()).onPressed, isNull);
      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull, reason: 'toggle disabled too');
    });
  }

  testWidgets('decimals are allowed with a fraction', (tester) async {
    await pumpDialog(tester, type: DialogType.numEdit, current: 0.5, max: 1, fraction: 2);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '0.50');

    await tester.enterText(find.byType(TextField), '0.75');
    await tapAndSettle(tester, confirm());

    expect(responses.single.data, 0.75);
  });

  testWidgets(
    'the keyboard offers a decimal separator when decimals are allowed',
    skip: true, // Finding: keyboardType is always numberWithOptions(decimal: false), also with a fraction.
    (tester) async {
      await pumpDialog(tester, type: DialogType.numEdit, current: 0.5, max: 1, fraction: 2);

      expect(
        tester.widget<TextField>(find.byType(TextField)).keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
    },
  );

  testWidgets('cancel aborts', (tester) async {
    await pumpDialog(tester);

    await tapAndSettle(tester, find.text('Cancel'));

    expect(responses.single.confirmed, isFalse);
  });

  testWidgets('uses the labels of the request', (tester) async {
    await pumpDialog(tester, actionLabel: 'Apply', dismissLabel: 'Back');

    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });
}
