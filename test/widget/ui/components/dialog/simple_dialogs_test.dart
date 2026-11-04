/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/machine_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/confirmation_dialog.dart';
import 'package:mobileraker/ui/components/dialog/select_printer/select_printer_dialog.dart';
import 'package:mobileraker/ui/components/dialog/text_input/text_input_dialog.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  late List<DialogResponse> responses;

  setUp(() => responses = []);

  group('TextInputDialog', () {
    Future<void> pumpDialog(WidgetTester tester, TextInputDialogArguments args) async {
      await tester.pumpApp(
        TextInputDialog(
          request: DialogRequest(type: DialogType.textInput, title: 'Rename Webcam', data: args),
          completer: responses.add,
        ),
      );
      await tester.pumpAndSettle();
    }

    ButtonStyleButton action(WidgetTester tester) => tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('Confirm'), matching: find.bySubtype<ButtonStyleButton>()),
    );

    testWidgets('shows the title, the initial value and the decoration', (tester) async {
      await pumpDialog(
        tester,
        const TextInputDialogArguments(initialValue: 'Nozzle cam', labelText: 'Name', helperText: 'Shown in the app'),
      );

      expect(find.text('Rename Webcam'), findsOneWidget);
      expect(find.text('Nozzle cam'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Shown in the app'), findsOneWidget);
    });

    testWidgets('confirm returns the edited text', (tester) async {
      await pumpDialog(tester, const TextInputDialogArguments(initialValue: 'Nozzle cam'));

      await tester.enterText(find.byType(TextField), 'Bed cam');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(responses.single.confirmed, isTrue);
      expect(responses.single.data, 'Bed cam');
    });

    testWidgets('an invalid value shows the error and disables confirm', (tester) async {
      await pumpDialog(
        tester,
        TextInputDialogArguments(initialValue: 'Nozzle cam', validator: FormBuilderValidators.required()),
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('This field cannot be empty.'), findsOneWidget);
      expect(action(tester).onPressed, isNull);
    });

    testWidgets('the value transformer is applied to the result', (tester) async {
      await pumpDialog(tester, TextInputDialogArguments(initialValue: '', valueTransformer: (value) => value?.trim()));

      await tester.enterText(find.byType(TextField), '  Chamber  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(responses.single.data, 'Chamber');
    });

    testWidgets('cancel aborts', (tester) async {
      await pumpDialog(tester, const TextInputDialogArguments(initialValue: 'Nozzle cam'));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(responses.single.confirmed, isFalse);
    });
  });

  group('ConfirmationDialog', () {
    Future<void> pumpDialog(WidgetTester tester, DialogRequest request) async {
      await tester.pumpApp(ConfirmationDialog(dialogRequest: request, completer: responses.add));
      await tester.pumpAndSettle();
    }

    testWidgets('shows title and body, confirm confirms', (tester) async {
      await pumpDialog(
        tester,
        DialogRequest(type: DialogType.confirm, title: 'Cancel print?', body: 'The print can not be resumed.'),
      );

      expect(find.text('Cancel print?'), findsOneWidget);
      expect(find.text('The print can not be resumed.'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(responses.single.confirmed, isTrue);
    });

    testWidgets('uses the labels of the request, dismiss does not confirm', (tester) async {
      await pumpDialog(tester, DialogRequest(type: DialogType.confirm, actionLabel: 'Delete', dismissLabel: 'Keep'));

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(responses.single.confirmed, isFalse);
    });
  });

  group('SelectPrinterDialog', () {
    final voron = Fixtures.machine(uuid: 'm1', name: 'Voron');
    final ender = Fixtures.machine(uuid: 'm2', name: 'Ender 3');
    final prusa = Fixtures.machine(uuid: 'm3', name: 'Prusa MK4');
    late FakeSelectedMachineService selection;

    Future<void> pumpDialog(WidgetTester tester) async {
      selection = FakeSelectedMachineService();
      await tester.pumpApp(
        SelectPrinterDialog(
          request: DialogRequest(type: CommonDialogs.activeMachine),
          completer: responses.add,
        ),
        overrides: [
          ...connectedMachineOverrides(voron),
          ...connectedMachineOverrides(ender, selected: false),
          ...connectedMachineOverrides(prusa, selected: false),
          allMachinesProvider.overrideWith(() => FakeAllMachines([voron, ender, prusa])),
          selectedMachineServiceProvider.overrideWithValue(selection),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('names the active machine and lists the others', (tester) async {
      await pumpDialog(tester);

      expect(find.text('Select Machine'), findsOneWidget);
      expect(find.text('Active Machine: Voron'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Ender 3'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Prusa MK4'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Voron'), findsNothing);
    });

    testWidgets('tapping a machine selects it and closes the dialog', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('Prusa MK4'));
      await tester.pump();

      expect(selection.selections, [prusa]);
      expect(responses.single.confirmed, isTrue);
    });

    testWidgets('cancel keeps the active machine', (tester) async {
      await pumpDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(selection.selections, isEmpty);
      expect(responses.single.confirmed, isFalse);
    });
  });
}
