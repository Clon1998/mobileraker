/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/screens/printers/add/printers_add_controller.dart';
import 'package:mobileraker/ui/screens/printers/add/printers_add_page.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  late FakeMachineService machines;

  /// Pumps the add page. The connection test reports [connection] instead of opening real connections.
  Future<void> pumpPage(
    WidgetTester tester, {
    TestConnectionState connection = const TestConnectionState(wsState: ClientState.connected, httpState: true),
    bool supporter = true,
    int maxNonSupporterMachines = 0,
    int existingMachines = 0,
  }) async {
    machines = FakeMachineService();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const PrinterAddPage()),
        GoRoute(path: '/dashboard', name: AppRoute.dashBoard.name, builder: (_, _) => const Text('dashboard')),
      ],
    );
    await tester.pumpRouterApp(
      router,
      overrides: [
        ...uiServiceOverrides(),
        ...remoteConfigOverrides(ints: {'non_suporters_max_printers': maxNonSupporterMachines}),
        machineServiceProvider.overrideWithValue(machines),
        allMachinesProvider.overrideWith(
          () => FakeAllMachines([for (var i = 0; i < existingMachines; i++) Fixtures.machine(uuid: 'm$i')]),
        ),
        isSupporterProvider.overrideWithValue(supporter),
        testConnectionControllerProvider.overrideWith(() => _FixedConnectionTest(connection)),
      ],
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> fillSimpleForm(
    WidgetTester tester, {
    String name = 'Voron',
    String url = 'voron.local',
    String? key,
  }) async {
    await tester.enterText(field('Displayname'), name);
    await tester.enterText(field('Printer - Address'), url);
    if (key != null) await tester.enterText(field('Moonraker - API Key'), key);
    await tester.pumpAndSettle();
  }

  testWidgets('starts by asking for the input mode', (tester) async {
    await pumpPage(tester);

    expect(find.text('Add New Printer'), findsOneWidget);
    expect(find.text('Simple'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('One-click OctoEverywhere setup'), findsOneWidget);
    expect(find.text('One-click Obico setup'), findsOneWidget);
  });

  testWidgets('simple mode: name, address, test and add', (tester) async {
    await pumpPage(tester);

    await tapText(tester, 'Simple');
    expect(find.text('Hint - Simple Mode'), findsOneWidget);
    expect(find.text('My Printer'), findsOneWidget, reason: 'default name');

    await fillSimpleForm(tester, key: 'secret');
    await tapText(tester, 'Test Connection');

    expect(find.text('Http Endpoint - Test'), findsOneWidget);
    expect(find.text('Valid'), findsNWidgets(2));
    expect(machines.added, isEmpty, reason: 'not added before the test step is confirmed');

    await tapText(tester, 'Continue');

    final added = machines.added.single;
    expect(added.name, 'Voron');
    expect(added.httpUri, Uri.parse('http://voron.local'));
    expect(added.apiKey, 'secret');
    expect(find.text('Printer Voron added!'), findsOneWidget);

    await tapText(tester, 'To the Dashboard');
    expect(find.text('dashboard'), findsOneWidget);
  });

  testWidgets('simple mode: the protocol prefix switches to https', (tester) async {
    await pumpPage(tester);
    await tapText(tester, 'Simple');

    await fillSimpleForm(tester); // the prefix only shows once the address has text
    await tapText(tester, 'http://');
    expect(find.text('https://'), findsOneWidget);
    await tapText(tester, 'Test Connection');
    await tapText(tester, 'Continue');

    expect(machines.added.single.httpUri, Uri.parse('https://voron.local'));
  });

  for (final (name, url, reason) in [('', 'voron.local', 'no name'), ('Voron', '', 'no address')]) {
    testWidgets('simple mode: the connection test needs a valid form ($reason)', (tester) async {
      await pumpPage(tester);
      await tapText(tester, 'Simple');

      await fillSimpleForm(tester, name: name, url: url);
      await tapText(tester, 'Test Connection');

      expect(find.text('Http Endpoint - Test'), findsNothing);
      expect(find.text('This field cannot be empty.'), findsOneWidget);
    });
  }

  testWidgets('a failed connection test warns but allows to continue anyway', (tester) async {
    await pumpPage(
      tester,
      connection: const TestConnectionState(
        wsState: ClientState.error,
        wsError: 'Connection refused',
        httpState: false,
        httpError: '404 - Not Found',
      ),
    );
    await tapText(tester, 'Simple');
    await fillSimpleForm(tester);
    await tapText(tester, 'Test Connection');

    expect(find.text('Connection refused'), findsOneWidget);
    expect(find.text('404 - Not Found'), findsOneWidget);
    expect(find.textContaining('having trouble connecting'), findsOneWidget);

    await tapText(tester, 'Continue Anyway');

    expect(machines.added, hasLength(1));
  });

  testWidgets('continuing waits for the connection test results', (tester) async {
    await pumpPage(tester, connection: const TestConnectionState(wsState: ClientState.connecting));
    await tapText(tester, 'Simple');
    await fillSimpleForm(tester);
    await tester.tap(find.text('Test Connection'));
    await tester.pump(const Duration(milliseconds: 500));

    final continueButton = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('Continue'), matching: find.bySubtype<ButtonStyleButton>()),
    );
    expect(continueButton.onPressed, isNull);
  });

  testWidgets('back returns to the previous step', (tester) async {
    await pumpPage(tester);
    await tapText(tester, 'Simple');

    await tapText(tester, 'Back');

    expect(find.text('Simple'), findsOneWidget);
    expect(find.text('Hint - Simple Mode'), findsNothing);
  });

  testWidgets('advanced mode shows the advanced form', (tester) async {
    await pumpPage(tester);

    await tapText(tester, 'Advanced');

    expect(find.text('Hint - Advanced Mode'), findsOneWidget);
    expect(field('Client timeout'), findsOneWidget);
  });

  testWidgets('non-supporters at the machine limit can not add another machine', (tester) async {
    await pumpPage(tester, supporter: false, maxNonSupporterMachines: 2, existingMachines: 2);

    expect(find.textContaining("You've reached the machine limit"), findsOneWidget);
    expect(find.text('Simple'), findsNothing);
  });

  testWidgets('non-supporters below the limit can add machines', (tester) async {
    await pumpPage(tester, supporter: false, maxNonSupporterMachines: 2, existingMachines: 1);

    expect(find.text('Simple'), findsOneWidget);
  });
}

class _FixedConnectionTest extends TestConnectionController {
  _FixedConnectionTest(this.result);

  final TestConnectionState result;

  @override
  TestConnectionState build() {
    final machine = ref.watch(printerAddViewControllerProvider).machineToAdd!;
    return result.copyWith(httpUri: machine.httpUri);
  }
}
