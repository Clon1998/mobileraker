/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';

import 'package:common/data/model/hive/machine.dart';
import 'package:common/exceptions/octo_everywhere_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/connection/machine_connection_guard.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;
  late FakeDialogService dialogs;

  Widget guard() => MachineConnectionGuard(onConnected: (context, uuid) => Text('connected $uuid'));

  /// Pumps the guard for [machine] with its websocket in [clientState]. Spinners never settle, so this pumps a fixed
  /// time.
  Future<void> pumpGuard(
    WidgetTester tester, {
    ClientState clientState = ClientState.connected,
    ClientType clientType = ClientType.local,
    Object? errorReason,
  }) async {
    rpc = FakeJsonRpcClient(clientType: clientType)..errorReason = errorReason;
    dialogs = FakeDialogService();
    await tester.pumpApp(
      guard(),
      overrides: [
        ...uiServiceOverrides(dialogs: dialogs),
        ...connectedMachineOverrides(machine, client: rpc, clientState: clientState),
      ],
    );
    await tester.pumpProviders();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('without a machine it welcomes the user and offers to add one', (tester) async {
    await tester.pumpApp(guard(), overrides: [selectedMachineProvider.overrideWithValue(const AsyncData(null))]);
    await tester.pumpAndSettle();

    expect(find.textContaining('kindly add a printer to Mobileraker'), findsOneWidget);
    expect(find.text('Add Machine'), findsOneWidget);
  });

  testWidgets('shows an error when the selected machine can not be loaded', (tester) async {
    await tester.pumpApp(
      guard(),
      overrides: [selectedMachineProvider.overrideWithValue(AsyncError('Hive box corrupt', StackTrace.empty))],
    );
    await tester.pumpAndSettle();

    expect(find.text('Error selecting active machine'), findsOneWidget);
    expect(find.text('Hive box corrupt'), findsOneWidget);
  });

  testWidgets('shows a spinner while the selected machine loads', (tester) async {
    await tester.pumpApp(guard(), overrides: [selectedMachineProvider.overrideWithValue(const AsyncLoading())]);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('connected and Klipper ready: shows the page', (tester) async {
    await pumpGuard(tester);

    expect(find.text('connected ${machine.uuid}'), findsOneWidget);
  });

  testWidgets('connecting locally', (tester) async {
    await pumpGuard(tester, clientState: ClientState.connecting);

    expect(tester.widget<FadingText>(find.byType(FadingText)).text, 'Trying to connect…');
    await tester.unmountApp();
  });

  testWidgets('connecting through a remote client', (tester) async {
    await pumpGuard(tester, clientState: ClientState.connecting, clientType: ClientType.octo);

    expect(tester.widget<FadingText>(find.byType(FadingText)).text, 'Trying to connect using remote client…');
    await tester.unmountApp();
  });

  testWidgets('disconnected: names the machine and reconnects', (tester) async {
    await pumpGuard(tester, clientState: ClientState.disconnected);

    expect(find.text('Lost connection to Voron (voron.local).'), findsOneWidget);
    expect(find.text('Edit machine settings'), findsNothing);

    await tester.tap(find.text('Reconnect'));
    await tester.pump();

    expect(rpc.openChannelCalls, 1);
  });

  testWidgets('error: explains, reconnects and links to the machine settings', (tester) async {
    await pumpGuard(tester, clientState: ClientState.error, errorReason: TimeoutException('ws'));

    expect(find.text('Machine is not reachable!'), findsOneWidget);
    expect(find.textContaining('Could not connect to Voron (voron.local).'), findsOneWidget);
    expect(find.text('Connection timeout'), findsOneWidget);
    expect(find.text('Edit machine settings'), findsOneWidget);

    await tester.tap(find.text('Reconnect'));
    await tester.pump();
    expect(rpc.openChannelCalls, 1);
  });

  testWidgets('error: the error chip opens the details', (tester) async {
    await pumpGuard(tester, clientState: ClientState.error, errorReason: TimeoutException('ws'));

    await tester.tap(find.text('Connection timeout'));
    await tester.pump();

    final request = dialogs.requests.single;
    expect(request.type, CommonDialogs.stacktrace);
    expect(request.title, 'Connection Error Details');
    expect(request.body, startsWith('A timeout occurred'));
  });

  for (final (reason, chip) in [
    (const SocketException('Connection refused', osError: OSError('refused', 111)), 'error 111 · Connection refused'),
    (const OctoEverywhereException('Tunnel down'), 'OctoEverywhere error: Tunnel down'),
    (null, 'Unknown connection error'),
  ]) {
    testWidgets('error chip for ${reason.runtimeType}: "$chip"', (tester) async {
      await pumpGuard(tester, clientState: ClientState.error, errorReason: reason);

      expect(find.text(chip), findsOneWidget);
    });
  }

  testWidgets('error with expired OctoEverywhere supporter perks links to OctoEverywhere instead of reconnecting', (
    tester,
  ) async {
    await pumpGuard(
      tester,
      clientState: ClientState.error,
      clientType: ClientType.octo,
      errorReason: const OctoEverywhereHttpException('No supporter perks', 605),
    );

    expect(find.text('Reconnect'), findsNothing);
    expect(find.text('More Details'), findsOneWidget);
    expect(find.textContaining('OctoEverywhere is not affiliated with Mobileraker'), findsOneWidget);
  });

  testWidgets('error: "edit machine settings" opens the settings of this machine', (tester) async {
    rpc = FakeJsonRpcClient()..errorReason = TimeoutException('ws');
    Object? pushedExtra;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: guard()),
        ),
        GoRoute(
          path: '/edit',
          name: AppRoute.printerEdit.name,
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
        ...connectedMachineOverrides(machine, client: rpc, clientState: ClientState.error),
      ],
    );
    await tester.pumpProviders();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Edit machine settings'));
    await tester.pumpAndSettle();

    expect(find.text('edit page'), findsOneWidget);
    expect(pushedExtra, isA<Machine>().having((m) => m.uuid, 'uuid', machine.uuid));
  });
}
