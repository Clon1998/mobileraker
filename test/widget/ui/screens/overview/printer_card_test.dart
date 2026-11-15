/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/screens/overview/components/printer_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine(uuid: 'm1', name: 'Printer 1');

  late FakeSelectedMachineService selection;
  late GoRouter router;

  Future<void> pumpCard(
    WidgetTester tester, {
    ClientState clientState = ClientState.connected,
    KlipperState klipperState = KlipperState.ready,
  }) async {
    selection = FakeSelectedMachineService();
    router = GoRouter(
      initialLocation: '/overview',
      routes: [
        GoRoute(
          path: '/overview',
          builder: (_, _) => Scaffold(body: SingleChildScrollView(child: PrinterCard(machine))),
        ),
        GoRoute(
          path: '/dashboard',
          name: AppRoute.dashBoard.name,
          builder: (_, _) => const Scaffold(body: Text('Dashboard page')),
        ),
      ],
    );
    await tester.pumpRouterApp(
      router,
      overrides: [
        ...connectedMachineOverrides(
          machine,
          clientState: clientState,
          klipper: Fixtures.klipper(state: klipperState, stateMessage: 'Some message'),
        ),
        ...uiServiceOverrides(),
        ...remoteConfigOverrides(),
        selectedMachineServiceProvider.overrideWithValue(selection),
      ],
    );
    // The cards animate continuously, so no pumpAndSettle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> expectTapOpensDashboard(WidgetTester tester) async {
    await tester.tap(find.text(machine.name));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(selection.selections, [machine]);
    expect(router.state.name, AppRoute.dashBoard.name);
    expect(find.text('Dashboard page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  group('tapping the card opens the dashboard', () {
    // E.g. a printer that is powered off: Moonraker is reachable, Klipper is not. The dashboard offers its power
    // devices, so the card must not be a dead end.
    for (final state in KlipperState.values.where((s) => s != KlipperState.ready)) {
      testWidgets('Klipper ${state.name}', (tester) async {
        await pumpCard(tester, klipperState: state);

        await expectTapOpensDashboard(tester);
      });
    }

    for (final state in [ClientState.disconnected, ClientState.error, ClientState.connecting]) {
      testWidgets('websocket ${state.name}', (tester) async {
        await pumpCard(tester, clientState: state);

        await expectTapOpensDashboard(tester);
      });
    }

    testWidgets('Klipper ready', (tester) async {
      await pumpCard(tester);

      await expectTapOpensDashboard(tester);
    });
  });
}
