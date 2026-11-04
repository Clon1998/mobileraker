/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/selection_bottom_sheet.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/sheet_router.dart';

void main() {
  setUpWidgetTests();

  const filaments = [
    SelectionOption(value: 'petg', label: 'PETG'),
    SelectionOption(value: 'silk', label: 'Silk PLA+'),
    SelectionOption(value: 'pla', label: 'PLA', selected: true),
    SelectionOption(value: 'abs', label: 'ABS', subtitle: 'Needs an enclosure'),
    SelectionOption(value: 'tpu', label: 'TPU', enabled: false),
  ];

  /// What the sheet was closed with (through the real bottom sheet service).
  late List<BottomSheetResult> popped;

  Future<void> openSheet(WidgetTester tester, SelectionBottomSheetArgs<String> args, {bool settle = true}) async {
    popped = [];
    final result = await tester.openSheet(
      BottomSheetConfig(type: SheetType.selections, data: args),
      settle: settle,
    );
    result.then(popped.add).ignore();
  }

  Future<void> search(WidgetTester tester, String term) async {
    await tester.enterText(find.byType(TextField), term);
    await tester.pump(); // rebuild starts the debounce timer
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  List<String> labels(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      if (tile.title case Text(:final data?) when filaments.any((f) => f.label == data)) data,
  ];

  BottomSheetResult result() => popped.single;

  testWidgets('lists the options with title, subtitle and selection', (tester) async {
    await openSheet(tester, const SelectionBottomSheetArgs(title: Text('Material'), options: filaments));

    expect(find.text('Material'), findsOneWidget);
    expect(labels(tester), ['PETG', 'Silk PLA+', 'PLA', 'ABS', 'TPU']);
    expect(find.text('Needs an enclosure'), findsOneWidget);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'PLA')).selected, isTrue);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'TPU')).enabled, isFalse);
  });

  testWidgets('tapping an option closes the sheet with it', (tester) async {
    await openSheet(tester, const SelectionBottomSheetArgs(options: filaments));

    await tester.tap(find.text('ABS'));
    await tester.pumpAndSettle();

    expect(result().confirmed, isTrue);
    expect(result().data, 'abs');
  });

  testWidgets('search filters the options', (tester) async {
    await openSheet(tester, const SelectionBottomSheetArgs(options: filaments));

    await search(tester, 'pla');

    expect(labels(tester), containsAll(['PLA', 'Silk PLA+']));
    expect(labels(tester), isNot(contains('PETG')));
  });

  testWidgets(
    'search lists the best match first',
    (tester) async {
      await openSheet(tester, const SelectionBottomSheetArgs(options: filaments));

      await search(tester, 'pla');

      expect(labels(tester).first, 'PLA');
    },
  );

  testWidgets('a search without results says so, clearing shows everything again', (tester) async {
    await openSheet(tester, const SelectionBottomSheetArgs(options: filaments));

    await search(tester, 'nylon carbon');
    expect(find.text('No results found'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(labels(tester), hasLength(5));
  });

  testWidgets('without search there is no search field', (tester) async {
    await openSheet(tester, const SelectionBottomSheetArgs(options: filaments, showSearch: false));

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('multi select toggles options and confirms them with select', (tester) async {
    await openSheet(tester, const SelectionBottomSheetArgs(options: filaments, multiSelect: true));

    await tester.tap(find.text('PETG'));
    await tester.tap(find.text('PLA'));
    await tester.pumpAndSettle();
    expect(popped, isEmpty, reason: 'tapping does not close the sheet');

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(result().data, ['petg'], reason: 'PLA was preselected and got deselected');
  });

  testWidgets('async options show a spinner until they are loaded', (tester) async {
    final options = Completer<List<SelectionOption<String>>>();
    await openSheet(tester, SelectionBottomSheetArgs(options: options.future), settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    options.complete(filaments);
    await tester.pumpAndSettle();

    expect(labels(tester), hasLength(5));
  });

  testWidgets('failing async options show the error', (tester) async {
    final options = Completer<List<SelectionOption<String>>>();
    await openSheet(tester, SelectionBottomSheetArgs(options: options.future), settle: false);

    options.completeError('Spoolman unreachable');
    await tester.pumpAndSettle();

    expect(find.text('Spoolman unreachable'), findsOneWidget);
  });

  testWidgets('onConfirmed replaces popping', (tester) async {
    List<dynamic>? confirmed;
    await openSheet(
      tester,
      // Typed like the app's callers: the sheet route casts the args to SelectionBottomSheetArgs<dynamic>.
      SelectionBottomSheetArgs(options: filaments, onConfirmed: (_, List<dynamic> values) => confirmed = values),
    );

    await tester.tap(find.text('ABS'));
    await tester.pumpAndSettle();

    expect(confirmed, ['abs']);
    expect(popped, isEmpty);
  });
}
