/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/screens/dashboard/components/editing_dashboard_card.dart';
import 'package:mobileraker/ui/screens/dashboard/layouts/dashboard_compact_layout_page.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();

  final status = DashboardComponent.create(type: DashboardComponentType.machineStatus);
  final limits = DashboardComponent.create(type: DashboardComponentType.limits);
  final multipliers = DashboardComponent.create(type: DashboardComponentType.multipliers);
  final tab = DashboardTab.create(name: 'General', icon: 'nozzle', components: [status, limits, multipliers]);

  // The layout's danger button needs the app's custom colors.
  final theme = ThemeData(
    extensions: const [CustomColors(danger: Colors.red, onDanger: Colors.white)],
  );

  late List<String> calls;

  Future<void> pumpPage(WidgetTester tester, {bool editing = false, bool supporter = true}) async {
    calls = [];
    await tester.pumpApp(
      DashboardCompactLayoutPage(
        machineUUID: machine.uuid,
        tab: tab,
        isEditing: editing,
        staticWidgets: const [Text('static banner')],
        onRequestedEdit: () => calls.add('edit'),
        onReorder: (t, from, to) => calls.add('reorder ${t.name} $from->$to'),
        onAddComponent: (t) => calls.add('add ${t.name}'),
        onRemoveComponent: (t, c) => calls.add('remove ${c.type.name}'),
        onRemove: (t) => calls.add('remove page ${t.name}'),
      ),
      theme: theme,
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(machine),
        isSupporterProvider.overrideWithValue(supporter),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('not editing', () {
    testWidgets('shows the static widgets and the live cards of the tab', (tester) async {
      await pumpPage(tester);

      expect(find.text('static banner'), findsOneWidget);
      expect(find.text('Standby'), findsOneWidget, reason: 'machine status card with live data');
      expect(find.text('Limits'), findsOneWidget);
      expect(find.text('Editing Mode'), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('a long press on a card requests the edit mode', (tester) async {
      await pumpPage(tester);

      await tester.longPress(find.text('Limits'));
      await tester.pumpAndSettle();

      expect(calls, ['edit']);
      await tester.unmountApp();
    });
  });

  group('editing', () {
    testWidgets('explains the edit mode and shows card previews instead of the static widgets', (tester) async {
      await pumpPage(tester, editing: true);

      expect(find.text('Editing Mode'), findsOneWidget);
      expect(find.text('static banner'), findsNothing);
      expect(find.byType(EditingDashboardCard), findsNWidgets(3));
      expect(find.textContaining('Only Mobileraker Supporters'), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('non-supporters are told that custom dashboards are a supporter feature', (tester) async {
      await pumpPage(tester, editing: true, supporter: false);

      expect(find.textContaining('custom'), findsWidgets);
      expect(find.byType(EditingDashboardCard), findsNWidgets(3), reason: 'they can still try it');
      await tester.unmountApp();
    });

    testWidgets('tapping a card reveals delete, which removes that card', (tester) async {
      await pumpPage(tester, editing: true);

      await tester.tap(find.byType(EditingDashboardCard).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      expect(calls, ['remove limits']);
      await tester.unmountApp();
    });

    testWidgets('tapping a revealed card again hides delete', (tester) async {
      await pumpPage(tester, editing: true);

      await tester.tap(find.byType(EditingDashboardCard).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete), findsOneWidget);

      // Away from the delete button in the middle.
      await tester.tapAt(tester.getTopLeft(find.byType(EditingDashboardCard).first) + const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(calls, isEmpty);
      await tester.unmountApp();
    });

    testWidgets('add card and remove page call back with the tab', (tester) async {
      await pumpPage(tester, editing: true);

      await tester.scrollUntilVisible(find.text('Remove Page'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Add Card'));
      await tester.tap(find.text('Remove Page'));
      await tester.pumpAndSettle();

      expect(calls, ['add General', 'remove page General']);
      await tester.unmountApp();
    });

    testWidgets('long press and drag reorders the cards', (tester) async {
      await pumpPage(tester, editing: true);

      final first = find.byType(EditingDashboardCard).first;
      final gesture = await tester.startGesture(tester.getCenter(first));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveBy(Offset(0, tester.getSize(first).height * 1.6), timeStamp: const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(calls.single, startsWith('reorder General 0->'));
      await tester.unmountApp();
    });
  });
}
