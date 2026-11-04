/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/data/repository/dashboard_layout_hive_repository.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/temperature_store_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/dashboard/components/editing_dashboard_card.dart';
import 'package:mobileraker/ui/screens/dashboard/customizable_dashboard_page.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/app_overrides.dart';

void main() {
  setUpWidgetTests();

  late Machine machine;
  late FakeMachineService machines;
  late FakeSnackBarService snackBars;
  late FakeDialogService dialogs;
  late _MemoryLayouts layouts;

  /// The machine's stored layout: a status card on "General", the limits on "Control".
  DashboardLayout storedLayout() => DashboardLayout(
    uuid: 'layout-1',
    name: 'Mine',
    created: DateTime(2026),
    tabs: [
      DashboardTab.create(
        name: 'General',
        icon: 'nozzle',
        components: [DashboardComponent.create(type: DashboardComponentType.machineStatus)],
      ),
      DashboardTab.create(
        name: 'Control',
        icon: 'sliders',
        components: [DashboardComponent.create(type: DashboardComponentType.limits)],
      ),
    ],
  );

  /// [supporter] only affects saving: the layout itself is always loaded like for a supporter (non-supporters get
  /// the default layout, whose cards need many more fakes).
  Future<void> pumpPage(WidgetTester tester, {bool supporter = true, DialogResponse? dialogResponse}) async {
    machine = Fixtures.machine().copyWith(dashboardLayout: 'layout-1');
    machines = FakeMachineService(machines: [machine]);
    snackBars = FakeSnackBarService();
    dialogs = FakeDialogService(response: dialogResponse);
    layouts = _MemoryLayouts()..stored['layout-1'] = storedLayout();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const CustomizableDashboardPage())],
    );
    await tester.pumpRouterApp(
      router,
      theme: ThemeData(
        extensions: const [CustomColors(danger: Colors.red, onDanger: Colors.white)],
      ),
      overrides: [
        ...uiServiceOverrides(snackBars: snackBars, dialogs: dialogs),
        ...connectedMachineOverrides(machine),
        ...remoteConfigOverrides(),
        ...pageExtrasOverrides(),
        machineServiceProvider.overrideWithValue(machines),
        allMachinesProvider.overrideWith(() => FakeAllMachines([machine])),
        isSupporterProvider.overrideWithValue(supporter),
        isSupporterAsyncProvider.overrideWithValue(const AsyncData(true)),
        dashboardLayoutHiveRepositoryProvider.overrideWithValue(layouts),
        temperatureStoresProvider(machine.uuid).overrideWith(NoTemperatureHistory.new),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> startEditing(WidgetTester tester) async {
    await tester.longPress(find.text('Standby'));
    await tester.pumpAndSettle();
  }

  Future<void> removeFirstCard(WidgetTester tester) async {
    await tester.tap(find.byType(EditingDashboardCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
  }

  /// Taps the [index]th page icon of the bottom navigation bar.
  Future<void> tapPage(WidgetTester tester, int index) async {
    await tester.tap(
      find.descendant(of: find.byType(AnimatedBottomNavigationBar), matching: find.byType(Icon)).at(index),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapIcon(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the first page of the stored layout, the bottom bar switches pages', (tester) async {
    await pumpPage(tester);

    expect(find.text('Standby'), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget, reason: 'idle FAB');

    await tapPage(tester, 1);

    expect(find.text('Limits').hitTestable(), findsOneWidget);
    expect(find.text('Standby').hitTestable(), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('a long press on a card starts the edit mode', (tester) async {
    await pumpPage(tester);

    await startEditing(tester);

    expect(find.text('Personalize Dashboard'), findsOneWidget);
    expect(find.text('Editing Mode'), findsOneWidget);
    expect(find.byType(EditingDashboardCard), findsWidgets);
    expect(find.byIcon(Icons.list), findsOneWidget, reason: 'layout FAB while editing');
    await tester.unmountApp();
  });

  testWidgets('saving persists the edited layout and assigns it to the machine', (tester) async {
    await pumpPage(tester);
    await startEditing(tester);
    await removeFirstCard(tester);

    await tapIcon(tester, Icons.save);

    expect(layouts.stored['layout-1']!.tabs.first.components, isEmpty);
    expect(machines.updated.single.dashboardLayout, 'layout-1');
    expect(snackBars.shown.map((s) => s.title), ['Layout saved!']);
    expect(find.text('Personalize Dashboard'), findsNothing, reason: 'back to the dashboard');
    await tester.unmountApp();
  });

  testWidgets('saving without changes just leaves the edit mode', (tester) async {
    await pumpPage(tester);
    await startEditing(tester);

    await tapIcon(tester, Icons.save);

    expect(machines.updated, isEmpty);
    expect(snackBars.shown, isEmpty);
    expect(find.text('Personalize Dashboard'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('a layout without any card is not saved', (tester) async {
    await pumpPage(tester);
    await startEditing(tester);
    await removeFirstCard(tester);
    await tapPage(tester, 1);
    await removeFirstCard(tester);

    await tapIcon(tester, Icons.save);

    expect(snackBars.shown.map((s) => s.title), ['Empty Layout!']);
    expect(machines.updated, isEmpty);
    expect(find.text('Personalize Dashboard'), findsOneWidget, reason: 'stays in edit mode');
    await tester.unmountApp();
  });

  testWidgets('non-supporters can try the edit mode but not save it', (tester) async {
    await pumpPage(tester, supporter: false);
    await startEditing(tester);
    await removeFirstCard(tester);

    await tapIcon(tester, Icons.save);

    expect(snackBars.shown.single.type, SnackbarType.warning);
    expect(machines.updated, isEmpty);
    expect(layouts.stored['layout-1']!.tabs.first.components, hasLength(1));
    await tester.unmountApp();
  });

  testWidgets('leaving with changes asks to discard them, confirming restores the layout', (tester) async {
    await pumpPage(tester, dialogResponse: DialogResponse.confirmed());
    await startEditing(tester);
    await removeFirstCard(tester);

    await tapIcon(tester, Icons.arrow_back);

    expect(dialogs.confirms.single, 'Discard changes?');
    expect(find.text('Personalize Dashboard'), findsNothing);
    expect(find.text('Standby'), findsOneWidget, reason: 'the removed card is back');
    expect(machines.updated, isEmpty);
    await tester.unmountApp();
  });

  testWidgets('declining the discard dialog keeps editing', (tester) async {
    await pumpPage(tester);
    await startEditing(tester);
    await removeFirstCard(tester);

    await tapIcon(tester, Icons.arrow_back);

    expect(find.text('Personalize Dashboard'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('leaving without changes does not ask', (tester) async {
    await pumpPage(tester);
    await startEditing(tester);

    await tapIcon(tester, Icons.arrow_back);

    expect(dialogs.confirms, isEmpty);
    expect(find.text('Personalize Dashboard'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('removing one of only two pages is refused', (tester) async {
    await pumpPage(tester);
    await startEditing(tester);

    await tester.scrollUntilVisible(find.text('Remove Page'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Remove Page'));
    await tester.pumpAndSettle();

    expect(snackBars.shown.map((s) => s.title), ["Can't remove page!"]);
    await tester.unmountApp();
  });
}

class _MemoryLayouts extends Fake implements DashboardLayoutHiveRepository {
  final Map<String, DashboardLayout> stored = {};

  @override
  Future<void> create(DashboardLayout entity) async => stored[entity.uuid] = entity;

  @override
  Future<void> update(DashboardLayout entity) async => stored[entity.uuid] = entity;

  @override
  Future<DashboardLayout?> read({String? id, int index = -1}) async => stored[id];

  @override
  Future<List<DashboardLayout>> all() async => stored.values.toList();
}
