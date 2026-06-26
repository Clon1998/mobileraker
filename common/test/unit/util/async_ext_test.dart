/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/async_ext.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

// A Notifier that exposes a mutable AsyncValue<int>.
// Used to drive selectAs with precise AsyncValue states (unit-test style).
class _AsyncValueNotifier extends Notifier<AsyncValue<int>> {
  @override
  AsyncValue<int> build() => const AsyncData(0);

  void set(AsyncValue<int> value) => state = value;
}

final _inputProvider = NotifierProvider<_AsyncValueNotifier, AsyncValue<int>>(_AsyncValueNotifier.new);

// A simple int counter used by integration tests to trigger FutureProvider reloads.
class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final _counterProvider = NotifierProvider<_Counter, int>(_Counter.new);

// A FutureProvider that watches _counterProvider so that incrementing the
// counter causes a dependency-change reload (isReloading), not a refresh.
final _futureProvider = FutureProvider<int>((ref) async => ref.watch(_counterProvider));

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  AsyncValue<String> readSelected(
    ProviderContainer container, {
    bool skipLoadingOnReload = false,
    bool skipError = false,
  }) {
    return container.read(
      _inputProvider.selectAs(
        (v) => v.toString(),
        skipLoadingOnReload: skipLoadingOnReload,
        skipError: skipError,
      ),
    );
  }

  // ── Unit tests: drive exact AsyncValue states via _inputProvider ──────────

  group('selectAs — unit tests', () {
    group('AsyncData input', () {
      test('plain AsyncData maps to AsyncData', () {
        final container = ProviderContainer.test();
        container.read(_inputProvider.notifier).set(const AsyncData(42));

        final result = readSelected(container);

        expect(result, isA<AsyncData<String>>());
        expect(result.value, '42');
        expect(result.isLoading, isFalse);
      });
    });

    group('initial AsyncLoading (no previous value)', () {
      test('maps to AsyncLoading with no value', () {
        final container = ProviderContainer.test();
        container.read(_inputProvider.notifier).set(const AsyncLoading());

        final result = readSelected(container);

        expect(result, isA<AsyncLoading<String>>());
        expect(result.hasValue, isFalse);
        expect(result.isLoading, isTrue);
      });

      test('skipLoadingOnReload has no effect when there is no previous value', () {
        final container = ProviderContainer.test();
        container.read(_inputProvider.notifier).set(const AsyncLoading());

        final result = readSelected(container, skipLoadingOnReload: true);

        expect(result, isA<AsyncLoading<String>>());
        expect(result.hasValue, isFalse);
      });
    });

    group('AsyncLoading with previous value — reload vs refresh', () {
      test('reload (isReloading=true) is preserved in output', () {
        final container = ProviderContainer.test();
        // Simulates a dependency-change rebuild: AsyncLoading(hasValue: true, isReloading: true)
        container.read(_inputProvider.notifier).set(const AsyncData(42).toLoading(false));

        final result = readSelected(container);

        expect(result.isLoading, isTrue);
        expect(result.isReloading, isTrue,
            reason: 'isReloading must propagate so consumers can distinguish reload from initial load');
        expect(result.isRefreshing, isFalse);
        expect(result.value, '42', reason: 'Previous value must be retained during reload');
      });

      test('refresh (isRefreshing=true) is preserved in output', () {
        final container = ProviderContainer.test();
        // Simulates an explicit invalidate: AsyncLoading(hasValue: true, isRefreshing: true)
        container.read(_inputProvider.notifier).set(const AsyncData(42).toLoading());

        final result = readSelected(container);

        expect(result.isLoading, isTrue);
        expect(result.isRefreshing, isTrue,
            reason: 'isRefreshing must propagate so consumers can show a refresh indicator');
        expect(result.isReloading, isFalse);
        expect(result.value, '42', reason: 'Previous value must be retained during refresh');
      });

      test('skipLoadingOnReload: reload returns clean AsyncData', () {
        final container = ProviderContainer.test();
        container.read(_inputProvider.notifier).set(const AsyncData(42).toLoading(false));

        final result = readSelected(container, skipLoadingOnReload: true);

        expect(result, isA<AsyncData<String>>());
        expect(result.isLoading, isFalse);
        expect(result.value, '42');
      });

      test('skipLoadingOnReload does not suppress explicit refresh', () {
        final container = ProviderContainer.test();
        container.read(_inputProvider.notifier).set(const AsyncData(42).toLoading());

        final result = readSelected(container, skipLoadingOnReload: true);

        // refresh is a user-triggered action and must still surface as loading
        expect(result.isLoading, isTrue);
        expect(result.isRefreshing, isTrue);
        expect(result.value, '42');
      });
    });

    group('AsyncError input', () {
      final error = Exception('test error');
      final stack = StackTrace.empty;

      test('AsyncError with no previous value maps to AsyncError', () {
        final container = ProviderContainer.test();
        container.read(_inputProvider.notifier).set(AsyncValue<int>.error(error, stack));

        final result = readSelected(container);

        expect(result, isA<AsyncError<String>>());
        expect((result as AsyncError<String>).error, error);
        expect(result.hasValue, isFalse);
      });

      test('AsyncError with previous value maps to AsyncError by default', () {
        final container = ProviderContainer.test();
        container.read(_inputProvider.notifier).set(const AsyncData(42).toError(error, stack));

        final result = readSelected(container);

        expect(result, isA<AsyncError<String>>());
        expect((result as AsyncError<String>).error, error);
      });

      test('skipError: AsyncError-with-value maps to AsyncData using last value', () {
        final container = ProviderContainer.test();
        container.read(_inputProvider.notifier).set(const AsyncData(42).toError(error, stack));

        final result = readSelected(container, skipError: true);

        expect(result, isA<AsyncData<String>>());
        expect(result.value, '42');
      });
    });

    group('selector transformation', () {
      test('applies selector function to the contained value', () {
        final container = ProviderContainer.test();
        container.read(_inputProvider.notifier).set(const AsyncData(100));

        final result = container.read(_inputProvider.selectAs((v) => 'value: $v'));

        expect(result.value, 'value: 100');
      });
    });
  });

  // ── Integration tests: real FutureProvider emitting actual Riverpod states ─
  //
  // These tests complement the unit tests above by exercising selectAs with
  // the real AsyncValue states that Riverpod produces internally during reload
  // and refresh. Critically, a FutureProvider emits AsyncData(isLoading: true)
  // during a dependency-change rebuild — a state that cannot be constructed
  // via public APIs in unit tests — covering the AsyncData branch of selectAs.

  group('selectAs — integration tests (real FutureProvider)', () {
    test('dependency-change reload: all loading states have isReloading=true', () async {
      final container = ProviderContainer.test();

      // Get initial data
      await container.read(_futureProvider.future);

      final seen = <AsyncValue<String>>[];
      container.listen(
        _futureProvider.selectAs((v) => v.toString()),
        (_, next) => seen.add(next),
      );

      // Incrementing the counter triggers a dependency change (reload, NOT a refresh)
      container.read(_counterProvider.notifier).increment();

      // Wait for the rebuild to settle
      await container.read(_futureProvider.future);

      final loadingStates = seen.where((s) => s.isLoading).toList();

      // There must be at least one loading state during a rebuild
      expect(loadingStates, isNotEmpty, reason: 'A reload must produce at least one loading state');

      for (final s in loadingStates) {
        expect(s.isReloading, isTrue,
            reason: 'A dependency-change reload must produce isReloading=true, '
                'not isRefreshing=true, so that consumers using '
                'AsyncValue(isLoading: true, isReloading: false) do not '
                'incorrectly show a loading indicator');
        expect(s.isRefreshing, isFalse);
        // Previous value must be available throughout the reload
        expect(s.value, '0', reason: 'Previous value must be retained during reload');
      }

      // Final state must reflect the new counter value
      expect(seen.last.value, '1');
    });

    test('explicit invalidate (refresh): all loading states have isRefreshing=true', () async {
      final container = ProviderContainer.test();

      await container.read(_futureProvider.future);

      final seen = <AsyncValue<String>>[];
      container.listen(
        _futureProvider.selectAs((v) => v.toString()),
        (_, next) => seen.add(next),
      );

      // invalidate() is an explicit refresh, not a dependency change
      container.invalidate(_futureProvider);

      await container.read(_futureProvider.future);

      final loadingStates = seen.where((s) => s.isLoading).toList();

      expect(loadingStates, isNotEmpty, reason: 'A refresh must produce at least one loading state');

      for (final s in loadingStates) {
        expect(s.isRefreshing, isTrue,
            reason: 'An explicit invalidate must produce isRefreshing=true');
        expect(s.isReloading, isFalse);
      }
    });

    test('skipLoadingOnReload: dependency-change reload emits no loading states', () async {
      final container = ProviderContainer.test();

      await container.read(_futureProvider.future);

      final seen = <AsyncValue<String>>[];
      container.listen(
        _futureProvider.selectAs((v) => v.toString(), skipLoadingOnReload: true),
        (_, next) => seen.add(next),
      );

      container.read(_counterProvider.notifier).increment();
      await container.read(_futureProvider.future);

      final loadingStates = seen.where((s) => s.isLoading).toList();

      expect(loadingStates, isEmpty,
          reason: 'skipLoadingOnReload must suppress all loading states during a dependency-change reload');
      expect(seen.last.value, '1');
    });
  });
}
