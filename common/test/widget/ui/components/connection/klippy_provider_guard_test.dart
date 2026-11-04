/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/ui/components/connection/klippy_provider_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

  Widget guard({bool skipKlipperReady = false, List<Widget>? errorChildren}) => KlippyProviderGuard(
    machineUUID: machine.uuid,
    skipKlipperReady: skipKlipperReady,
    klippyErrorChildren: errorChildren,
    onConnected: (context, uuid) => Text('connected $uuid'),
  );

  Future<void> pumpGuard(
    WidgetTester tester, {
    KlipperInstance? klipper,
    _ControllableKlipper? controllable,
    bool skipKlipperReady = false,
    List<Widget>? errorChildren,
  }) async {
    rpc = FakeJsonRpcClient();
    await tester.pumpApp(
      guard(skipKlipperReady: skipKlipperReady, errorChildren: errorChildren),
      wrapInScaffold: true,
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: klipper,
          klipperNotifier: controllable == null ? null : () => controllable,
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the child once Klipper is ready', (tester) async {
    await pumpGuard(tester);

    expect(find.text('connected ${machine.uuid}'), findsOneWidget);
  });

  testWidgets('shows the child while Klipper is starting', (tester) async {
    await pumpGuard(tester, klipper: Fixtures.klipper(state: KlipperState.startup));

    expect(find.text('connected ${machine.uuid}'), findsOneWidget);
  });

  for (final state in [KlipperState.shutdown, KlipperState.error]) {
    testWidgets('${state.name}: shows the state with restart Klipper and firmware', (tester) async {
      await pumpGuard(
        tester,
        klipper: Fixtures.klipper(state: state, stateMessage: 'MCU "mcu" shutdown'),
      );

      expect(find.textContaining('connected'), findsNothing);
      expect(find.text('MCU "mcu" shutdown'), findsOneWidget);
      expect(find.text('Restart Klipper'), findsOneWidget);
      expect(find.text('Restart Firmware'), findsOneWidget);
    });
  }

  testWidgets('disconnected: only offers to restart Klipper', (tester) async {
    await pumpGuard(tester, klipper: Fixtures.klipper(state: KlipperState.disconnected));

    expect(find.text('Restart Klipper'), findsOneWidget);
    expect(find.text('Restart Firmware'), findsNothing);
  });

  testWidgets('the restart buttons restart the Klipper service and the MCUs', (tester) async {
    await pumpGuard(tester, klipper: Fixtures.klipper(state: KlipperState.shutdown));

    await tester.tap(find.text('Restart Klipper'));
    await tester.tap(find.text('Restart Firmware'));
    await tester.pumpAndSettle();

    expect(rpc.methods, ['machine.services.restart', 'printer.firmware_restart']);
    expect(rpc.calls.first.params, {'service': 'klipper'});
  });

  testWidgets('shows the extra children below the Klippy error', (tester) async {
    await pumpGuard(
      tester,
      klipper: Fixtures.klipper(state: KlipperState.shutdown),
      errorChildren: [const Text('webcam')],
    );

    expect(find.text('webcam'), findsOneWidget);
  });

  testWidgets('with skipKlipperReady the child is shown despite a Klippy error', (tester) async {
    await pumpGuard(tester, klipper: Fixtures.klipper(state: KlipperState.shutdown), skipKlipperReady: true);

    expect(find.text('connected ${machine.uuid}'), findsOneWidget);
  });

  testWidgets('after Klipper was ready once, a later error keeps the child (the page shows it)', (tester) async {
    final klipper = _ControllableKlipper(Fixtures.klipper());
    await pumpGuard(tester, controllable: klipper);

    klipper.emit(Fixtures.klipper(state: KlipperState.shutdown));
    await tester.pumpAndSettle();

    expect(find.text('connected ${machine.uuid}'), findsOneWidget);
    expect(find.text('Restart Klipper'), findsNothing);
  });

  testWidgets('a failing Klipper query shows the error and retries it', (tester) async {
    final klipper = _ControllableKlipper(
      null,
      error: const MobilerakerException('wrapped', parentException: 'Socket closed'),
    );
    await pumpGuard(tester, controllable: klipper);

    expect(find.text('Error while fetching Klipper Data'), findsOneWidget);
    expect(find.text('Socket closed'), findsOneWidget, reason: 'shows the parent exception');

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(klipper.builds, 2);
  });

  testWidgets('unauthorized: asks for the API key and links to the printer settings', (tester) async {
    await pumpGuard(tester, klipper: Fixtures.klipper(state: KlipperState.unauthorized));

    expect(find.textContaining('add the API key'), findsOneWidget);
    expect(find.text('Printer Settings'), findsOneWidget);
  });

  testWidgets(
    'unauthorized: the printer settings button opens the settings of this machine',
    (tester) async {
      Object? pushedExtra;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: guard()),
          ),
          GoRoute(
            path: '/edit',
            name: 'printerEdit',
            builder: (_, state) {
              pushedExtra = state.extra;
              return const Text('edit page');
            },
          ),
        ],
      );
      await tester.pumpRouterApp(
        router,
        overrides: [
          ...uiServiceOverrides(),
          ...connectedMachineOverrides(machine, klipper: Fixtures.klipper(state: KlipperState.unauthorized)),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Printer Settings'));
      await tester.pumpAndSettle();

      expect(find.text('edit page'), findsOneWidget);
      expect(pushedExtra, isA<Machine>().having((m) => m.uuid, 'uuid', machine.uuid));
    },
  );
}

/// A Klipper whose state the test changes with [emit]; fails with [error] if given. Counts [builds] (retries).
class _ControllableKlipper extends Klipper {
  _ControllableKlipper(this.initial, {this.error});

  final KlipperInstance? initial;
  final Object? error;
  int builds = 0;

  @override
  Future<KlipperInstance> build(String machineUUID) async {
    builds++;
    if (error != null) throw error!;
    return initial!;
  }

  void emit(KlipperInstance instance) => state = AsyncData(instance);
}
