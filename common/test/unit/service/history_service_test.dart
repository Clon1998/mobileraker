/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/history_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart';
import 'package:test_support/test_support.dart';

import '../../test_utils.dart';

void main() {
  setUpAll(setupTestLogger);

  const uuid = 'test-machine';

  Map<String, dynamic> jobJson(int id) => {
    'job_id': '$id',
    'user': '_TRUSTED_USER_',
    'filename': 'part_$id.gcode',
    'status': 'completed',
    'start_time': 1762761600.0 + id * 3600,
    'end_time': 1762761600.0 + id * 3600 + 1200,
    'print_duration': 1000.0,
    'total_duration': 1200.0,
    'filament_used': 1000.0,
    'metadata': {'size': 1, 'modified': 1.0},
    'auxiliary_data': [],
    'exists': true,
  };

  late FakeJsonRpcClient rpc;
  late StreamController<Map<String, dynamic>> historyChanged;
  var jobCount = 2;
  var failing = false;

  int callsOf(String method) => rpc.calls.where((c) => c.method == method).length;

  /// The test has to dispose it, its timers must not outlive the test body.
  ProviderContainer makeContainer() {
    jobCount = 2;
    failing = false;
    rpc = FakeJsonRpcClient(
      responses: {
        'server.history.list': (_) {
          if (failing) throw StateError('history is not available');
          return {
            'jobs': [for (var i = jobCount; i > 0; i--) jobJson(i)],
          };
        },
        'server.history.totals': (_) => {
          'job_totals': {
            'total_jobs': jobCount,
            'total_time': 2400.0,
            'total_print_time': 2000.0,
            'total_filament_used': 2000.0,
            'longest_job': 1200.0,
            'longest_print': 1000.0,
          },
        },
      },
    );
    historyChanged = StreamController.broadcast();
    addTearDown(historyChanged.close);

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        jrpcClientProvider(uuid).overrideWithValue(rpc),
        jrpcClientStateProvider(uuid).overrideWith((ref) async => ClientState.connected),
        jrpcMethodEventProvider(uuid, 'notify_history_changed').overrideWith((ref) => historyChanged.stream),
      ],
    );
    return container;
  }

  /// Listens like a widget that came (back) into view.
  ProviderSubscription<AsyncValue<T>> listen<T>(ProviderContainer container, ProviderListenable<AsyncValue<T>> p) =>
      container.listen(p, (_, _) {});

  group('jobHistoryProvider', () {
    testWidgets('keeps the jobs for a while after the last listener is gone', (tester) async {
      final container = makeContainer();
      final provider = jobHistoryProvider(uuid, null);

      var sub = listen(container, provider);
      await tester.pump();
      expect(sub.read().value, hasLength(2));
      sub.close();

      await tester.pump(historyKeepAlive - const Duration(seconds: 1));
      sub = listen(container, provider);
      expect(sub.read().value, hasLength(2), reason: 'available right away, e.g. back on the dashboard');
      await tester.pump();
      expect(callsOf('server.history.list'), 1);
      sub.close();

      // Coming back restarted the time it is kept.
      await tester.pump(historyKeepAlive - const Duration(seconds: 1));
      sub = listen(container, provider);
      await tester.pump();
      expect(callsOf('server.history.list'), 1);
      sub.close();

      await tester.pump(historyKeepAlive + const Duration(seconds: 1));
      sub = listen(container, provider);
      expect(sub.read().hasValue, isFalse);
      await tester.pump();
      expect(sub.read().value, hasLength(2));
      expect(callsOf('server.history.list'), 2);
      sub.close();
      container.dispose();
    });

    testWidgets('fetches a change of the history that happened while nobody listened', (tester) async {
      final container = makeContainer();
      final provider = jobHistoryProvider(uuid, null);

      var sub = listen(container, provider);
      await tester.pump();
      sub.close();
      await tester.pump(const Duration(seconds: 10));

      jobCount = 3;
      historyChanged.add({'action': 'added'});
      await tester.pump(const Duration(seconds: 10));

      sub = listen(container, provider);
      expect(sub.read().value, isNotNull, reason: 'the kept jobs are shown until the new ones arrived');
      await tester.pump(const Duration(seconds: 1));
      expect(sub.read().value, hasLength(3));
      expect(callsOf('server.history.list'), 2);
      sub.close();
      container.dispose();
    });

    testWidgets('refetches on a change of the history while it is listened to', (tester) async {
      final container = makeContainer();
      final sub = listen(container, jobHistoryProvider(uuid, null));
      await tester.pump();

      jobCount = 3;
      historyChanged.add({'action': 'added'});
      await tester.pump(const Duration(seconds: 1));

      expect(sub.read().value, hasLength(3));
      sub.close();
      container.dispose();
    });

    testWidgets('does not keep a failed request', (tester) async {
      final container = makeContainer();
      final provider = jobHistoryProvider(uuid, null);
      failing = true;

      var sub = listen(container, provider);
      await tester.pump();
      expect(sub.read().hasError, isTrue);
      sub.close();
      await tester.pump(const Duration(seconds: 1));

      failing = false;
      sub = listen(container, provider);
      await tester.pump();
      expect(sub.read().value, hasLength(2));
      sub.close();
      container.dispose();
    });
  });

  group('historyTotalsProvider', () {
    testWidgets('keeps the totals for a while after the last listener is gone', (tester) async {
      final container = makeContainer();
      final provider = historyTotalsProvider(uuid);

      var sub = listen(container, provider);
      await tester.pump();
      expect(sub.read().value?.totalJobs, 2);
      sub.close();

      await tester.pump(historyKeepAlive - const Duration(seconds: 1));
      sub = listen(container, provider);
      expect(sub.read().value?.totalJobs, 2);
      await tester.pump();
      expect(callsOf('server.history.totals'), 1);
      sub.close();

      await tester.pump(historyKeepAlive + const Duration(seconds: 1));
      sub = listen(container, provider);
      await tester.pump();
      expect(callsOf('server.history.totals'), 2);
      sub.close();
      container.dispose();
    });
  });
}
