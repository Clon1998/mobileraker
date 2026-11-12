/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/data/dto/history/history_params.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/history_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/misc.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/screens/history/history_page.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart' show SmartRefresher;
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;
  late GoRouter router;

  /// The jobs are numbered from the most recent one (1), an hour apart.
  Map<String, dynamic> jobJson(int number) => {
    'job_id': '$number',
    'user': '_TRUSTED_USER_',
    'filename': 'part_$number.gcode',
    'status': 'completed',
    'start_time': 1762761600.0 - number * 3600,
    'end_time': 1762761600.0 - number * 3600 + 1200,
    'print_duration': 1000.0,
    'total_duration': 1200.0,
    'filament_used': 1000.0,
    'metadata': {'size': 1, 'modified': 1.0, 'filament_type': 'PLA'},
    'auxiliary_data': [],
    'exists': true,
  };

  List<HistoricalPrintJob> jobs(int count) => [for (var i = 1; i <= count; i++) HistoricalPrintJob.fromJson(jobJson(i))];

  /// The request of the second step.
  const secondStep = HistoryParams(start: 0, limit: 100, since: null, before: null, order: SortKind.descending);

  /// A printer whose history has [total] jobs.
  Future<void> pumpPage(WidgetTester tester, {required int total, List<Override> overrides = const []}) async {
    rpc = FakeJsonRpcClient(
      responses: {
        'server.history.list': (params) => {
          'jobs': [for (var i = 1; i <= total && i <= ((params?['limit'] as int?) ?? 50); i++) jobJson(i)],
        },
        'server.history.totals': (_) => {
          'job_totals': {
            'total_jobs': total,
            'total_time': total * 1200.0,
            'total_print_time': total * 1000.0,
            'total_filament_used': total * 1000.0,
            'longest_job': 1200.0,
            'longest_print': 1000.0,
          },
        },
      },
    );
    router = GoRouter(
      initialLocation: '/history',
      routes: [
        GoRoute(path: '/history', name: AppRoute.history.name, builder: (_, _) => const HistoryPage()),
        GoRoute(path: '/other', builder: (_, _) => const Scaffold(body: Text('Other page'))),
      ],
    );
    await tester.pumpRouterApp(
      router,
      overrides: [
        ...uiServiceOverrides(),
        ...remoteConfigOverrides(),
        ...connectedMachineOverrides(machine, client: rpc, klipper: Fixtures.klipper(components: ['history'])),
        allMachinesProvider.overrideWith(() => FakeAllMachines([machine])),
        isSupporterProvider.overrideWithValue(false),
        ...overrides,
      ],
    );
    await tester.pumpAndSettle();
  }

  List<RecordedRpcCall> listCalls() => rpc.calls.where((c) => c.method == 'server.history.list').toList();

  /// Scrolls down until [finder] is built. Does not wait for animations: the list shows a spinner while it loads.
  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(finder, 400, scrollable: find.byType(Scrollable).first, maxScrolls: 100);

  testWidgets('lists the jobs lazily in slivers', (tester) async {
    await pumpPage(tester, total: 40);

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.text('part_1'), findsOneWidget);
    expect(find.text('part_40'), findsNothing, reason: 'only what is in view is built');

    await scrollTo(tester, find.text('part_40'));
    expect(find.text('part_1'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('pull to refresh reloads the jobs and the totals, like the other pages', (tester) async {
    await pumpPage(tester, total: 12);
    expect(find.byType(SmartRefresher), findsOneWidget);

    await tester.drag(find.text('part_1'), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(listCalls(), hasLength(2));
    expect(rpc.methods.where((m) => m == 'server.history.totals'), hasLength(2));
    expect(find.text('part_1'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('tells that the end of the history is reached', (tester) async {
    await pumpPage(tester, total: 12);
    expect(find.text('No older prints'), findsNothing, reason: 'the end is not in view');

    await scrollTo(tester, find.text('No older prints'));
    await tester.pumpAndSettle();

    expect(find.text('part_12'), findsOneWidget);
    expect(find.text('Loading older prints…'), findsNothing);
    expect(listCalls(), hasLength(1));
    await tester.unmountApp();
  });

  testWidgets('an empty history has no end marker', (tester) async {
    await pumpPage(tester, total: 0);

    expect(find.text('No prints yet. They show up here once a print was started.'), findsOneWidget);
    expect(find.text('No older prints'), findsNothing);
    expect(find.text('Loading older prints…'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('loads the older jobs once the end of the list comes into view', (tester) async {
    await pumpPage(tester, total: 60);
    expect(listCalls(), hasLength(1), reason: 'the top of the list does not load more');
    expect(listCalls().single.params, isNull);

    await scrollTo(tester, find.text('part_60'));
    await tester.pumpAndSettle();

    expect(listCalls(), hasLength(2));
    expect(listCalls().last.params, containsPair('limit', 100));

    await scrollTo(tester, find.text('No older prints'));
    await tester.pumpAndSettle();
    expect(listCalls(), hasLength(2), reason: 'the second step was not full, there is nothing older');
    await tester.unmountApp();
  });

  testWidgets('keeps loading while each step is full', (tester) async {
    await pumpPage(tester, total: 120);

    await scrollTo(tester, find.text('part_120'));
    await scrollTo(tester, find.text('No older prints'));
    await tester.pumpAndSettle();

    expect([for (final c in listCalls().skip(1)) c.params['limit']], [100, 150]);
    await tester.unmountApp();
  });

  testWidgets('shows that older jobs are being loaded', (tester) async {
    final older = Completer<List<HistoricalPrintJob>>();
    await pumpPage(
      tester,
      total: 50,
      overrides: [jobHistoryProvider(machine.uuid, secondStep).overrideWith((ref) => older.future)],
    );
    expect(find.text('Loading older prints…'), findsNothing, reason: 'the end is not in view');

    await scrollTo(tester, find.text('Loading older prints…'));
    await tester.pump();
    await tester.pump();

    // The request is pending: the jobs loaded so far and the indicator stay.
    expect(find.text('Loading older prints…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('part_50'), findsOneWidget);
    expect(find.text('No older prints'), findsNothing);

    older.complete(jobs(70));
    await tester.pumpAndSettle();
    expect(find.text('Loading older prints…'), findsNothing);

    await scrollTo(tester, find.text('No older prints'));
    expect(find.text('part_70'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('offers to retry if the older jobs could not be loaded', (tester) async {
    var attempts = 0;
    await pumpPage(
      tester,
      total: 50,
      overrides: [
        jobHistoryProvider(machine.uuid, secondStep).overrideWith(
          (ref) => attempts++ == 0 ? Future.error(StateError('timeout')) : Future.value(jobs(70)),
        ),
      ],
    );

    await scrollTo(tester, find.text('Could not load older prints.'));
    await tester.pumpAndSettle();
    expect(find.text('part_50'), findsOneWidget, reason: 'the jobs loaded so far stay');
    expect(find.text('Loading older prints…'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load older prints.'), findsNothing);
    await scrollTo(tester, find.text('No older prints'));
    expect(find.text('part_70'), findsOneWidget);
    await tester.unmountApp();
  });

  int callsOf(String method) => rpc.calls.where((c) => c.method == method).length;

  testWidgets('shows the history right away when the page is opened again', (tester) async {
    await pumpPage(tester, total: 12);

    // Leaves the page, like switching to the dashboard.
    router.go('/other');
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPage), findsNothing);
    await tester.pump(const Duration(minutes: 1));

    router.go('/history');
    await tester.pump();
    await tester.pump();

    expect(find.text('part_1'), findsOneWidget, reason: 'no loading state');
    expect(find.text('12'), findsOneWidget, reason: 'the totals are kept too');
    await tester.pumpAndSettle();
    expect(callsOf('server.history.list'), 1);
    expect(callsOf('server.history.totals'), 1);
    await tester.unmountApp();
  });

  testWidgets('fetches the history again once it was not used for a while', (tester) async {
    await pumpPage(tester, total: 12);

    router.go('/other');
    await tester.pumpAndSettle();
    await tester.pump(historyKeepAlive + const Duration(seconds: 1));

    router.go('/history');
    await tester.pumpAndSettle();

    expect(find.text('part_1'), findsOneWidget);
    expect(callsOf('server.history.list'), 2);
    expect(callsOf('server.history.totals'), 2);
    await tester.unmountApp();
  });
}
