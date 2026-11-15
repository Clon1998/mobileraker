/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/screens/overview/components/printer_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine(uuid: 'm1', name: 'Printer 1');

  late FakeSelectedMachineService selection;
  late FakeBottomSheetService bottomSheets;
  late FakeJsonRpcClient rpc;
  late GoRouter router;

  Future<void> pumpCard(
    WidgetTester tester, {
    ClientState clientState = ClientState.connected,
    KlipperState klipperState = KlipperState.ready,
    List<Map<String, dynamic>>? powerDevices,
  }) async {
    selection = FakeSelectedMachineService();
    bottomSheets = FakeBottomSheetService();
    rpc = FakeJsonRpcClient(
      responses: {
        'machine.device_power.devices': (_) => {'devices': powerDevices ?? []},
        'machine.device_power.post_device': (params) => {params['device']: params['action']},
      },
    );
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
          client: rpc,
          clientState: clientState,
          klipper: Fixtures.klipper(
            state: klipperState,
            stateMessage: 'Some message',
            components: [if (powerDevices != null) 'power'],
          ),
        ),
        ...uiServiceOverrides(bottomSheets: bottomSheets),
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

  group('power button', () {
    Map<String, dynamic> device(String name, String status) => {
      'device': name,
      'status': status,
      'type': 'gpio',
      'locked_while_printing': false,
    };

    final powerButton = find.byKey(const Key('overviewPowerButton'));

    for (final state in [KlipperState.disconnected, KlipperState.startup, KlipperState.shutdown, KlipperState.error]) {
      testWidgets('Klipper ${state.name}: opens the power devices sheet', (tester) async {
        await pumpCard(tester, klipperState: state, powerDevices: [device('printer', 'off')]);

        await tester.tap(powerButton);
        await tester.pump(const Duration(milliseconds: 500));

        expect(bottomSheets.shown.single.type, SheetType.powerDevices);
        expect(bottomSheets.shown.single.data, machine.uuid);
        expect(rpc.methods, isNot(contains('machine.device_power.post_device')), reason: 'the sheet switches');
        expect(selection.selections, isEmpty, reason: 'the button does not open the dashboard');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('sits next to the other actions', (tester) async {
      await pumpCard(
        tester,
        klipperState: KlipperState.error,
        powerDevices: [device('printer', 'off'), device('light', 'on')],
      );

      final restart = tester.getRect(find.text('Restart Klipper'));
      final power = tester.getRect(powerButton);
      expect(power.center.dy, closeTo(restart.center.dy, 1));
      expect(power.left, greaterThan(restart.right));
    });

    testWidgets('hidden without power devices', (tester) async {
      await pumpCard(tester, klipperState: KlipperState.disconnected, powerDevices: [device('_psu', 'off')]);

      expect(powerButton, findsNothing);
      expect(find.text('Restart Klipper'), findsOneWidget);
    });

    testWidgets('hidden without the power component', (tester) async {
      await pumpCard(tester, klipperState: KlipperState.disconnected);

      expect(powerButton, findsNothing);
      expect(rpc.methods, isNot(contains('machine.device_power.devices')));
    });

    testWidgets('hidden while Klipper is ready or initializing', (tester) async {
      for (final state in [KlipperState.ready, KlipperState.initializing, KlipperState.unauthorized]) {
        await pumpCard(tester, klipperState: state, powerDevices: [device('printer', 'on')]);

        expect(powerButton, findsNothing, reason: state.name);
      }
    });
  });
}
