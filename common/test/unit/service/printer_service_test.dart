/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/dto/server/moonraker_version.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../test_utils.dart';
import 'printer_service_test.mocks.dart';

@GenerateMocks([JsonRpcClient, SnackBarService, DialogService, FileService])
void main() {
  const uuid = 'test';

  // Minimal JRPC responses shared across tests.
  const listResponse = RpcResponse(jsonrpc: '2.0', id: 1, result: {
    'objects': ['toolhead', 'gcode_move', 'print_stats', 'configfile'],
  });

  const queryResponse = RpcResponse(jsonrpc: '2.0', id: 1, result: {
    'status': {
      'toolhead': {'position': [0.0, 0.0, 0.0, 0.0]},
      'gcode_move': {
        'speed_factor': 1.0,
        'speed': 0.0,
        'extrude_factor': 1.0,
        'absolute_coordinates': true,
        'absolute_extrude': true,
        'homing_origin': [0.0, 0.0, 0.0, 0.0],
        'position': [0.0, 0.0, 0.0, 0.0],
        'gcode_position': [0.0, 0.0, 0.0, 0.0],
      },
      'print_stats': {
        'state': 'standby',
        'filename': '',
        'total_duration': 0.0,
        'print_duration': 0.0,
        'filament_used': 0.0,
        'message': '',
      },
      'configfile': {'save_config_pending': false},
    },
  });

  const subscribeResponse = RpcResponse(jsonrpc: '2.0', id: 1, result: {});

  setUpAll(() {
    setupTestLogger();
    provideDummy<RpcResponse>(const RpcResponse(jsonrpc: '2.0', id: 0, result: {}));
    provideDummy<GCodeFile>(const GCodeFile(name: 'dummy.gcode', parentPath: '/', modified: 0, size: 0));
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Factory helpers
  // ──────────────────────────────────────────────────────────────────────────

  MockJsonRpcClient makeRpc() {
    final rpc = MockJsonRpcClient();
    when(rpc.clientType).thenReturn(ClientType.local);
    when(rpc.uri).thenReturn(Uri.parse('ws://localhost:7125/websocket'));
    return rpc;
  }

  MockFileService makeFileService() {
    final fs = MockFileService();
    when(fs.getGCodeMetadata(any)).thenAnswer(
      (_) async => const GCodeFile(name: 'test.gcode', parentPath: '/', modified: 0, size: 0),
    );
    return fs;
  }

  ProviderContainer makeContainer(
    MockJsonRpcClient rpc, {
    KlipperInstance? klippy,
    StreamController<Map<String, dynamic>>? statusUpdateCtrl,
    MockFileService? fileService,
    MockSnackBarService? snackBarService,
  }) {
    final k = klippy ??
        KlipperInstance(
          klippyConnected: true,
          klippyState: KlipperState.ready,
          moonrakerVersion: MoonrakerVersion.fallback(),
        );

    final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
      jrpcClientProvider(uuid).overrideWithValue(rpc),
      klipperProvider(uuid).overrideWith(() => _FixedKlipperNotifier(k)),
      fileServiceProvider(uuid).overrideWithValue(fileService ?? makeFileService()),
      snackBarServiceProvider.overrideWithValue(snackBarService ?? MockSnackBarService()),
      dialogServiceProvider.overrideWithValue(MockDialogService()),
      jrpcMethodEventProvider(uuid, 'notify_status_update').overrideWith(
        (_) => (statusUpdateCtrl ?? StreamController<Map<String, dynamic>>.broadcast()).stream,
      ),
    ]);
    return container;
  }

  void stubFullRefresh(MockJsonRpcClient rpc) {
    when(rpc.sendJRpcMethod('printer.objects.list')).thenAnswer((_) async => listResponse);
    when(rpc.sendJRpcMethod('printer.objects.query', params: anyNamed('params')))
        .thenAnswer((_) async => queryResponse);
    when(rpc.sendJRpcMethod('printer.objects.subscribe', params: anyNamed('params')))
        .thenAnswer((_) async => subscribeResponse);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tests
  // ──────────────────────────────────────────────────────────────────────────

  test('stays loading when klippy is not connected', () async {
    final rpc = makeRpc();
    final disconnected = KlipperInstance(
      klippyConnected: false,
      klippyState: KlipperState.disconnected,
      moonrakerVersion: MoonrakerVersion.fallback(),
    );
    final container = makeContainer(rpc, klippy: disconnected);

    // Read the provider but don't await — it should still be loading.
    final state = container.read(printerProvider(uuid));
    expect(state.isLoading, isTrue);
    expect(state.hasValue, isFalse);

    // No JRPC calls should be made while disconnected.
    verifyNever(rpc.sendJRpcMethod(any));
  });

  test('fetches printer objects when klippy is connected', () async {
    final rpc = makeRpc();
    stubFullRefresh(rpc);
    final container = makeContainer(rpc);

    final printer = await container.read(printerProvider(uuid).future);

    expect(printer, isNotNull);
    verify(rpc.sendJRpcMethod('printer.objects.list')).called(1);
    verify(rpc.sendJRpcMethod('printer.objects.query', params: anyNamed('params'))).called(1);
    verify(rpc.sendJRpcMethod('printer.objects.subscribe', params: anyNamed('params'))).called(1);
  });

  test('fetches printer when klippy transitions from disconnected to connected', () async {
    final rpc = makeRpc();
    stubFullRefresh(rpc);

    final ready = KlipperInstance(
      klippyConnected: true,
      klippyState: KlipperState.ready,
      moonrakerVersion: MoonrakerVersion.fallback(),
    );

    final container = ProviderContainer.test(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(rpc),
      klipperProvider(uuid).overrideWith(() => _ControllableKlipperNotifier()),
      fileServiceProvider(uuid).overrideWithValue(makeFileService()),
      snackBarServiceProvider.overrideWithValue(MockSnackBarService()),
      dialogServiceProvider.overrideWithValue(MockDialogService()),
      jrpcMethodEventProvider(uuid, 'notify_status_update').overrideWith(
        (_) => StreamController<Map<String, dynamic>>.broadcast().stream,
      ),
    ]);

    // Keep printerProvider alive between reads — without a persistent listener
    // the auto-dispose timer fires during the await below and disposes the
    // provider while it is still in loading state.
    container.listen(printerProvider(uuid), (_, __) {});

    // Initially loading — no JRPC calls.
    expect(container.read(printerProvider(uuid)).isLoading, isTrue);
    verifyNever(rpc.sendJRpcMethod(any));

    // Push klippy connected → triggers PrinterNotifier rebuild.
    (container.read(klipperProvider(uuid).notifier) as _ControllableKlipperNotifier).pushState(ready);

    // The first build returned a never-completing Completer future.  Awaiting
    // provider.future directly would hang because Riverpod does not complete
    // abandoned Completer futures on rebuild.  Instead, pump the event queue so
    // the scheduler fires, the new build runs its JRPC fetches, and the state
    // settles to AsyncData before we inspect it.
    await pumpEventQueue();

    expect(container.read(printerProvider(uuid)).hasValue, isTrue);
    verify(rpc.sendJRpcMethod('printer.objects.list')).called(1);
  });

  test('applies notify_status_update incrementally without rebuild', () async {
    final rpc = makeRpc();
    stubFullRefresh(rpc);
    final statusCtrl = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(statusCtrl.close);

    final container = makeContainer(rpc, statusUpdateCtrl: statusCtrl);

    // Keep printerProvider alive so that the incremental state update is not
    // lost when the auto-dispose timer fires during pumpEventQueue().
    container.listen(printerProvider(uuid), (_, __) {});

    await container.read(printerProvider(uuid).future);

    // Only 1 fetch so far.
    verify(rpc.sendJRpcMethod('printer.objects.list')).called(1);

    // Inject a status update that changes print state but keeps filename empty.
    // Keeping filename='' avoids triggering _updateCurrentFile as a side effect.
    statusCtrl.add({
      'params': [
        {
          'print_stats': {
            'state': 'printing',
            'filename': '',
            'total_duration': 30.0,
            'print_duration': 30.0,
            'filament_used': 1.5,
            'message': '',
          }
        }
      ],
    });
    await pumpEventQueue();

    final updatedState = container.read(printerProvider(uuid));
    expect(updatedState.hasValue, isTrue);
    expect(updatedState.requireValue.print.state.name, 'printing');

    // State was mutated in-place — no rebuild, no additional list fetch.
    verifyNever(rpc.sendJRpcMethod('printer.objects.list'));
  });

  test('refreshPrinter() on notifier re-fetches and awaits completion', () async {
    final rpc = makeRpc();
    stubFullRefresh(rpc);
    final container = makeContainer(rpc);

    await container.read(printerProvider(uuid).future);
    verify(rpc.sendJRpcMethod('printer.objects.list')).called(1);

    await container.read(printerProvider(uuid).notifier).refreshPrinter();
    verify(rpc.sendJRpcMethod('printer.objects.list')).called(1);
  });

  test('JRPC timeout during build puts provider in error state and shows snackbar', () async {
    final rpc = makeRpc();
    when(rpc.sendJRpcMethod('printer.objects.list')).thenAnswer(
      (_) async => throw JRpcTimeoutError('printer.objects.list timed out'),
    );
    final snackBar = MockSnackBarService();
    final container = makeContainer(rpc, snackBarService: snackBar);

    // In Riverpod 3.x, a failing build enters AsyncError(isLoading: true)
    // during the retry delay, so provider.future never resolves. Use a
    // listener that fires on the first hasError transition instead.
    final completer = Completer<AsyncValue<Printer>>();
    final sub = container.listen(printerProvider(uuid), (_, next) {
      if (next.hasError && !completer.isCompleted) completer.complete(next);
    }, fireImmediately: true);
    addTearDown(sub.close);

    final result = await completer.future;

    expect(result.hasError, isTrue);
    expect(result.error, isA<MobilerakerException>());
    verify(snackBar.showForMachine(uuid, any)).called(greaterThanOrEqualTo(1));
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('returns to loading when klippy disconnects after printer is loaded', () async {
    final rpc = makeRpc();
    stubFullRefresh(rpc);

    final ready = KlipperInstance(
      klippyConnected: true,
      klippyState: KlipperState.ready,
      moonrakerVersion: MoonrakerVersion.fallback(),
    );
    final disconnected = KlipperInstance(
      klippyConnected: false,
      klippyState: KlipperState.disconnected,
      moonrakerVersion: MoonrakerVersion.fallback(),
    );

    final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
      jrpcClientProvider(uuid).overrideWithValue(rpc),
      klipperProvider(uuid).overrideWith(() => _ControllableKlipperNotifier()),
      fileServiceProvider(uuid).overrideWithValue(makeFileService()),
      snackBarServiceProvider.overrideWithValue(MockSnackBarService()),
      dialogServiceProvider.overrideWithValue(MockDialogService()),
      jrpcMethodEventProvider(uuid, 'notify_status_update').overrideWith(
        (_) => StreamController<Map<String, dynamic>>.broadcast().stream,
      ),
    ]);
    container.listen(printerProvider(uuid), (_, __) {});

    // Push connected klippy → printer loads.
    (container.read(klipperProvider(uuid).notifier) as _ControllableKlipperNotifier).pushState(ready);
    await pumpEventQueue();
    expect(container.read(printerProvider(uuid)).hasValue, isTrue);

    // Push disconnected klippy → printer should return to loading.
    (container.read(klipperProvider(uuid).notifier) as _ControllableKlipperNotifier).pushState(disconnected);
    await pumpEventQueue();

    final state = container.read(printerProvider(uuid));
    // Riverpod 3.x keeps the previous AsyncData value while the provider
    // rebuilds (isLoading: true), so hasValue stays true during reload.
    expect(state.isLoading, isTrue);
    expect(state.hasError, isFalse);
  });

  test('with exclude_object in objects list', () async {
    final rpc = makeRpc();

    when(rpc.sendJRpcMethod('printer.objects.list')).thenAnswer(
      (_) async => const RpcResponse(jsonrpc: '2.0', id: 1, result: {
        'objects': ['exclude_object', 'toolhead', 'gcode_move', 'print_stats', 'configfile'],
      }),
    );
    when(rpc.sendJRpcMethod('printer.objects.query', params: anyNamed('params')))
        .thenAnswer((_) async => const RpcResponse(jsonrpc: '2.0', id: 1, result: {
              'status': {
                'exclude_object': {'objects': [], 'excluded_objects': [], 'current_object': null},
                'toolhead': {'position': [0.0, 0.0, 0.0, 0.0]},
                'gcode_move': {
                  'speed_factor': 1.0,
                  'speed': 0.0,
                  'extrude_factor': 1.0,
                  'absolute_coordinates': true,
                  'absolute_extrude': true,
                  'homing_origin': [0.0, 0.0, 0.0, 0.0],
                  'position': [0.0, 0.0, 0.0, 0.0],
                  'gcode_position': [0.0, 0.0, 0.0, 0.0],
                },
                'print_stats': {
                  'state': 'standby',
                  'filename': '',
                  'total_duration': 0.0,
                  'print_duration': 0.0,
                  'filament_used': 0.0,
                  'message': '',
                },
                'configfile': {'save_config_pending': false},
              },
            }));
    when(rpc.sendJRpcMethod('printer.objects.subscribe', params: anyNamed('params')))
        .thenAnswer((_) async => subscribeResponse);

    final container = makeContainer(rpc);
    final printer = await container.read(printerProvider(uuid).future);

    expect(printer, isNotNull);
    expect(printer.excludeObject, isNotNull);
  });

  test('PrinterGCodeStore fetches initial store and appends commands', () async {
    final rpc = makeRpc();
    when(rpc.addMethodListener(any, 'notify_gcode_response')).thenReturn(null);
    when(rpc.removeMethodListener(any, 'notify_gcode_response')).thenReturn(true);
    when(rpc.sendJRpcMethod('server.gcode_store')).thenAnswer(
      (_) async => const RpcResponse(jsonrpc: '2.0', id: 1, result: {
        'gcode_store': [
          {'message': 'G28', 'time': 1.0, 'type': 'command'},
        ],
      }),
    );

    final container = makeContainer(rpc);
    final store = await container.read(printerGCodeStoreProvider(uuid).future);
    expect(store.length, 1);
    expect(store.first.message, 'G28');

    container.read(printerGCodeStoreProvider(uuid).notifier).appendCommand('G1 X10');
    final updated = container.read(printerGCodeStoreProvider(uuid)).requireValue;
    expect(updated.length, 2);
    expect(updated.last.message, 'G1 X10');
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// Test helpers
// ──────────────────────────────────────────────────────────────────────────────

class _FixedKlipperNotifier extends Klipper {
  final KlipperInstance _value;
  _FixedKlipperNotifier(this._value);

  @override
  Future<KlipperInstance> build(String machineUUID) async => _value;
}

class _ControllableKlipperNotifier extends Klipper {
  // Use a Completer so build() stays pending until pushState is explicitly
  // called.  Returning a value directly (even via async =>) schedules a .then
  // microtask that fires during pumpEventQueue and overwrites any state already
  // set by pushState, causing a spurious rebuild.
  final _completer = Completer<KlipperInstance>();

  @override
  Future<KlipperInstance> build(String machineUUID) => _completer.future;

  void pushState(KlipperInstance instance) {
    if (!_completer.isCompleted) {
      _completer.complete(instance);
    } else {
      state = AsyncData(instance);
    }
  }
}
