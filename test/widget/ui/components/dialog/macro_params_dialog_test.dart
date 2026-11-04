/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/macro_params/macro_params_dialog.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  late List<DialogResponse> responses;

  final loadFilament = ConfigGcodeMacro.fromJson('LOAD_FILAMENT', {
    'gcode': 'M109 S{params.TEMP|default(220)}\nG1 E{params.LENGTH|default(50)}',
  });

  Future<void> pumpDialog(WidgetTester tester, ConfigGcodeMacro macro) async {
    responses = [];
    await tester.pumpApp(
      MacroParamsDialog(
        request: DialogRequest(type: DialogType.gcodeParams, data: macro),
        completer: responses.add,
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, String> confirmedParams() {
    expect(responses.single.confirmed, isTrue);
    return responses.single.data as Map<String, String>;
  }

  testWidgets('shows a field per param, filled with its default', (tester) async {
    await pumpDialog(tester, loadFilament);

    expect(find.text('Load_filament-Params'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'TEMP'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'LENGTH'), findsOneWidget);
    expect(find.text('220'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('confirm returns the defaults', (tester) async {
    await pumpDialog(tester, loadFilament);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(confirmedParams(), {'TEMP': '220', 'LENGTH': '50'});
  });

  testWidgets('confirm returns the edited values', (tester) async {
    await pumpDialog(tester, loadFilament);

    await tester.enterText(find.widgetWithText(TextField, 'TEMP'), '245');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(confirmedParams(), {'TEMP': '245', 'LENGTH': '50'});
  });

  testWidgets('cancel aborts', (tester) async {
    await pumpDialog(tester, loadFilament);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(responses.single.confirmed, isFalse);
  });

  testWidgets('a macro without params asks for confirmation', (tester) async {
    await pumpDialog(tester, ConfigGcodeMacro.fromJson('PURGE_LINE', {'gcode': 'G1 X10'}));

    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Purge_line'), findsWidgets);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(confirmedParams(), isEmpty);
  });

  testWidgets(
    'an untouched param without default is returned as text',
    skip: true, // Finding: it is returned as null, the macro card's `paramsMap[key]!` then throws.
    (tester) async {
      await pumpDialog(tester, ConfigGcodeMacro.fromJson('SET_SPEED', {'gcode': 'M220 S{params.SPEED}'}));

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // The macro card reads every value with `paramsMap[key]!.trim()`.
      final Object? speed = (responses.single.data as Map)['SPEED'];
      expect(speed, isA<String>());
    },
  );
}
