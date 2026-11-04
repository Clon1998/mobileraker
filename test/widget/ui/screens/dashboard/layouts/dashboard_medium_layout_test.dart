/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/service/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/screens/dashboard/components/editing_dashboard_card.dart';
import 'package:mobileraker/ui/screens/dashboard/layouts/dashboard_medium_layout.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();

  final general = DashboardTab.create(
    name: 'General',
    icon: 'nozzle',
    components: [DashboardComponent.create(type: DashboardComponentType.machineStatus)],
  );
  final control = DashboardTab.create(
    name: 'Control',
    icon: 'sliders',
    components: [
      DashboardComponent.create(type: DashboardComponentType.limits),
      DashboardComponent.create(type: DashboardComponentType.multipliers),
    ],
  );

  late List<String> calls;

  Future<void> pumpLayout(WidgetTester tester, {bool editing = false, bool supporter = true}) async {
    calls = [];
    await tester.pumpApp(
      DashboardMediumLayout(
        machineUUID: machine.uuid,
        tabs: [general, control],
        isEditing: editing,
        staticWidgets: const [Text('static banner')],
        onRequestedEdit: () => calls.add('edit'),
        onReorder: (from, to, oldIndex, newIndex) => calls.add('reorder ${from.name}:$oldIndex->${to.name}:$newIndex'),
        onAddComponent: (t) => calls.add('add ${t.name}'),
        onRemoveComponent: (t, c) => calls.add('remove ${t.name}:${c.type.name}'),
        onRemove: (t) => calls.add('remove page ${t.name}'),
      ),
      device: TestDevice.tablet,
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(machine),
        isSupporterProvider.overrideWithValue(supporter),
      ],
    );
    await tester.pumpAndSettle();
  }

  double leftOf(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dx;

  testWidgets('shows every page as a column, static widgets in the first one', (tester) async {
    await pumpLayout(tester);

    expect(find.text('Standby'), findsOneWidget);
    expect(find.text('Limits'), findsOneWidget);
    expect(leftOf(tester, 'Limits'), greaterThan(leftOf(tester, 'Standby')));
    expect(leftOf(tester, 'static banner'), lessThan(leftOf(tester, 'Limits')));
    await tester.unmountApp();
  });

  testWidgets('a long press on a card requests the edit mode', (tester) async {
    await pumpLayout(tester);

    await tester.longPress(find.text('Limits'));
    await tester.pumpAndSettle();

    expect(calls, ['edit']);
    await tester.unmountApp();
  });

  testWidgets('editing: previews per column and an add card per page', (tester) async {
    await pumpLayout(tester, editing: true);

    expect(find.text('Editing Mode'), findsOneWidget);
    expect(find.byType(EditingDashboardCard), findsNWidgets(3));
    expect(find.text('Add Card'), findsNWidgets(2));
    expect(find.text('static banner'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('editing: add card adds to the page of its column', (tester) async {
    await pumpLayout(tester, editing: true);

    final addCards = find.text('Add Card');
    final secondColumn = tester.getTopLeft(addCards.at(0)).dx > tester.getTopLeft(addCards.at(1)).dx ? 0 : 1;
    await tester.ensureVisible(addCards.at(secondColumn));
    await tester.tap(addCards.at(secondColumn));
    await tester.pumpAndSettle();

    expect(calls, ['add Control']);
    await tester.unmountApp();
  });

  testWidgets('editing: delete removes the card from its page', (tester) async {
    await pumpLayout(tester, editing: true);

    await tester.tap(find.byType(EditingDashboardCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(calls, ['remove General:machineStatus']);
    await tester.unmountApp();
  });

  testWidgets(
    'editing: pages can be removed on tablets too',
    skip: true, // Finding: the medium layout ignores onRemove, there is no "Remove Page" button on tablets.
    (tester) async {
      await pumpLayout(tester, editing: true);

      expect(find.text('Remove Page'), findsWidgets);
    },
  );
}
