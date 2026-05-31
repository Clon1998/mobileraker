/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../test_utils.dart';
import 'klipper_notifier_test.mocks.dart';

@GenerateMocks([JsonRpcClient])
void main() {
  setUpAll(() {
    setupTestLogger();
    provideDummy<RpcResponse>(RpcResponse.fromJson(jsonDecode('{"jsonrpc":"2.0","id":1,"result":{}}')));
  });

  const uuid = 'test-machine';

  // Minimal server.info response: klippy connected and ready.
  RpcResponse serverInfoResponse({bool klippyConnected = true, String klippyState = 'ready'}) =>
      RpcResponse(jsonrpc: '2.0', id: 1, result: {
        'klippy_connected': klippyConnected,
        'klippy_state': klippyState,
        'moonraker_version': 'v0.8.0',
        'components': <String>[],
        'failed_components': <String>[],
        'registered_directories': <String>[],
        'warnings': <String>[],
        'missing_klippy_requirements': <String>[],
        'websocket_count': 1,
        'api_version': [1, 2, 1],
        'api_version_string': '1.2.1',
      });

  // Minimal printer.info response.
  RpcResponse printerInfoResponse({String state = 'ready', String stateMessage = 'Printer is ready'}) =>
      RpcResponse(jsonrpc: '2.0', id: 1, result: {
        'state': state,
        'state_message': stateMessage,
        'klipper_path': '/home/pi/klipper',
        'config_file': '/home/pi/printer.cfg',
        'software_version': 'v0.11.0',
        'hostname': 'test-host',
        'cpu_info': '4 core ARM',
        'python_path': '/home/pi/klippy-env/bin/python',
        'log_file': '/home/pi/klipper.log',
      });

  ProviderContainer makeContainer(
    MockJsonRpcClient mockRpc, {
    StreamController<Map<String, dynamic>>? klippyReadyCtrl,
    StreamController<Map<String, dynamic>>? klippyShutdownCtrl,
    StreamController<Map<String, dynamic>>? klippyDisconnectedCtrl,
    ClientState clientState = ClientState.connected,
  }) {
    when(mockRpc.identifyConnection(any, any)).thenAnswer((_) async {});
    when(mockRpc.clientType).thenReturn(ClientType.local);
    when(mockRpc.uri).thenReturn(Uri.parse('ws://localhost:7125/websocket'));
    final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
      jrpcClientStateProvider(uuid).overrideWith((ref) async => clientState),
      versionInfoProvider.overrideWith((ref) async => PackageInfo(
            appName: 'test',
            packageName: 'com.test',
            version: '1.0.0',
            buildNumber: '1',
          )),
      machineProvider(uuid).overrideWith((ref) async => null),
      jrpcMethodEventProvider(uuid, 'notify_klippy_ready').overrideWith(
          (ref) => (klippyReadyCtrl ?? StreamController<Map<String, dynamic>>.broadcast()).stream),
      jrpcMethodEventProvider(uuid, 'notify_klippy_shutdown').overrideWith(
          (ref) => (klippyShutdownCtrl ?? StreamController<Map<String, dynamic>>.broadcast()).stream),
      jrpcMethodEventProvider(uuid, 'notify_klippy_disconnected').overrideWith(
          (ref) => (klippyDisconnectedCtrl ?? StreamController<Map<String, dynamic>>.broadcast()).stream),
    ]);
    return container;
  }

  test('returns disconnected instance when JRPC is not connected', () async {
    final mockRpc = MockJsonRpcClient();

    final container = makeContainer(mockRpc, clientState: ClientState.disconnected);
    final instance = await container.read(klipperProvider(uuid).future);

    expect(instance.klippyConnected, false);
    expect(instance.klippyState, KlipperState.disconnected);
    verifyNever(mockRpc.sendJRpcMethod(any));
  });

  test('returns error instance when JRPC is in error state', () async {
    final mockRpc = MockJsonRpcClient();

    final container = makeContainer(mockRpc, clientState: ClientState.error);
    final instance = await container.read(klipperProvider(uuid).future);

    expect(instance.klippyConnected, false);
    expect(instance.klippyState, KlipperState.error);
    verifyNever(mockRpc.sendJRpcMethod(any));
  });

  test('server.info failure puts provider in error state', () async {
    final mockRpc = MockJsonRpcClient();
    when(mockRpc.sendJRpcMethod('server.info')).thenAnswer(
      (_) async => throw JRpcError(-32601, 'Method not found'),
    );

    final container = makeContainer(mockRpc);

    // In Riverpod 3.x, a failing build enters AsyncError(isLoading: true)
    // while the retry is pending, so isLoading is always true. Check hasError.
    final completer = Completer<AsyncValue<KlipperInstance>>();
    final sub = container.listen(klipperProvider(uuid), (_, next) {
      if (next.hasError && !completer.isCompleted) completer.complete(next);
    }, fireImmediately: true);
    addTearDown(sub.close);

    final result = await completer.future;

    expect(result.hasError, isTrue);
    expect(result.error, isA<JRpcError>());
    verifyNever(mockRpc.sendJRpcMethod('printer.info'));
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('initial build: polls server.info then printer.info when klippy is immediately ready', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.info')).thenAnswer((_) async => serverInfoResponse());
    when(mockRpc.sendJRpcMethod('printer.info')).thenAnswer((_) async => printerInfoResponse());

    final container = makeContainer(mockRpc);
    final instance = await container.read(klipperProvider(uuid).future);

    expect(instance.klippyConnected, true);
    expect(instance.klippyState, KlipperState.ready);
    verify(mockRpc.sendJRpcMethod('server.info')).called(1);
    verify(mockRpc.sendJRpcMethod('printer.info')).called(1);
  });

  test('polls server.info until klippy connects, then fetches printer.info', () async {
    final mockRpc = MockJsonRpcClient();
    var serverCallCount = 0;

    when(mockRpc.sendJRpcMethod('server.info')).thenAnswer((_) async {
      serverCallCount++;
      return serverCallCount == 1
          ? serverInfoResponse(klippyConnected: false, klippyState: 'disconnected')
          : serverInfoResponse(klippyConnected: true, klippyState: 'ready');
    });
    when(mockRpc.sendJRpcMethod('printer.info')).thenAnswer((_) async => printerInfoResponse());

    final container = makeContainer(mockRpc);

    // Use a completer to wait until the provider reaches the final ready state.
    final completer = Completer<KlipperInstance>();
    final sub = container.listen(klipperProvider(uuid), (_, next) {
      if (next.value?.klippyConnected == true &&
          next.value?.klippyState == KlipperState.ready &&
          !completer.isCompleted) {
        completer.complete(next.value!);
      }
    }, fireImmediately: true);
    addTearDown(sub.close);

    final instance = await completer.future;

    expect(serverCallCount, greaterThanOrEqualTo(2));
    verify(mockRpc.sendJRpcMethod('printer.info')).called(1);
    expect(instance.klippyConnected, true);
    expect(instance.klippyState, KlipperState.ready);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('polls printer.info until klipper reaches ready state', () async {
    final mockRpc = MockJsonRpcClient();
    var printerCallCount = 0;

    when(mockRpc.sendJRpcMethod('server.info')).thenAnswer((_) async => serverInfoResponse());
    when(mockRpc.sendJRpcMethod('printer.info')).thenAnswer((_) async {
      printerCallCount++;
      return printerCallCount == 1
          ? printerInfoResponse(state: 'startup', stateMessage: 'Starting up')
          : printerInfoResponse(state: 'ready', stateMessage: 'Printer is ready');
    });

    final container = makeContainer(mockRpc);

    final completer = Completer<KlipperInstance>();
    final sub = container.listen(klipperProvider(uuid), (_, next) {
      if (next.value?.klippyState == KlipperState.ready && !completer.isCompleted) {
        completer.complete(next.value!);
      }
    }, fireImmediately: true);
    addTearDown(sub.close);

    final instance = await completer.future;

    expect(printerCallCount, greaterThanOrEqualTo(2));
    expect(instance.klippyState, KlipperState.ready);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('notify_klippy_ready triggers a rebuild and re-polls', () async {
    final mockRpc = MockJsonRpcClient();
    final readyCtrl = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(readyCtrl.close);

    var serverCallCount = 0;
    when(mockRpc.sendJRpcMethod('server.info')).thenAnswer((_) async {
      serverCallCount++;
      return serverInfoResponse();
    });
    when(mockRpc.sendJRpcMethod('printer.info')).thenAnswer((_) async => printerInfoResponse());

    final container = makeContainer(mockRpc, klippyReadyCtrl: readyCtrl);
    final sub = container.listen(klipperProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(klipperProvider(uuid).future);
    expect(serverCallCount, 1);

    // Simulate klippy ready notification
    readyCtrl.add({'params': []});
    await pumpEventQueue();
    await container.read(klipperProvider(uuid).future);

    expect(serverCallCount, greaterThan(1));
  });

  test('notify_klippy_shutdown triggers a rebuild and re-polls', () async {
    final mockRpc = MockJsonRpcClient();
    final shutdownCtrl = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(shutdownCtrl.close);

    var serverCallCount = 0;
    when(mockRpc.sendJRpcMethod('server.info')).thenAnswer((_) async {
      serverCallCount++;
      return serverInfoResponse();
    });
    when(mockRpc.sendJRpcMethod('printer.info')).thenAnswer((_) async => printerInfoResponse());

    final container = makeContainer(mockRpc, klippyShutdownCtrl: shutdownCtrl);
    final sub = container.listen(klipperProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(klipperProvider(uuid).future);
    expect(serverCallCount, 1);

    shutdownCtrl.add({'params': []});
    await pumpEventQueue();
    await container.read(klipperProvider(uuid).future);

    expect(serverCallCount, greaterThan(1));
  });

  test('notify_klippy_disconnected triggers a rebuild and re-polls', () async {
    final mockRpc = MockJsonRpcClient();
    final disconnectedCtrl = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(disconnectedCtrl.close);

    var serverCallCount = 0;
    when(mockRpc.sendJRpcMethod('server.info')).thenAnswer((_) async {
      serverCallCount++;
      return serverInfoResponse();
    });
    when(mockRpc.sendJRpcMethod('printer.info')).thenAnswer((_) async => printerInfoResponse());

    final container = makeContainer(mockRpc, klippyDisconnectedCtrl: disconnectedCtrl);
    final sub = container.listen(klipperProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(klipperProvider(uuid).future);
    expect(serverCallCount, 1);

    disconnectedCtrl.add({'params': []});
    await pumpEventQueue();
    await container.read(klipperProvider(uuid).future);

    expect(serverCallCount, greaterThan(1));
  });

  test('refreshKlippy() triggers a full re-poll and awaits completion', () async {
    final mockRpc = MockJsonRpcClient();
    var callCount = 0;

    when(mockRpc.sendJRpcMethod('server.info')).thenAnswer((_) async {
      callCount++;
      return serverInfoResponse();
    });
    when(mockRpc.sendJRpcMethod('printer.info')).thenAnswer((_) async => printerInfoResponse());

    final container = makeContainer(mockRpc);
    final sub = container.listen(klipperProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(klipperProvider(uuid).future);
    expect(callCount, 1);

    await container.read(klipperProvider(uuid).notifier).refreshKlippy();
    expect(callCount, 2);
  });

  test('KlippyService command methods send correct JRPC calls', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.info')).thenAnswer((_) async => serverInfoResponse());
    when(mockRpc.sendJRpcMethod('printer.info')).thenAnswer((_) async => printerInfoResponse());
    when(mockRpc.sendJRpcMethod('printer.firmware_restart'))
        .thenAnswer((_) async => RpcResponse(jsonrpc: '2.0', id: 1, result: {}));
    when(mockRpc.sendJRpcMethod('machine.reboot'))
        .thenAnswer((_) async => RpcResponse(jsonrpc: '2.0', id: 1, result: {}));
    when(mockRpc.sendJRpcMethod('machine.shutdown'))
        .thenAnswer((_) async => RpcResponse(jsonrpc: '2.0', id: 1, result: {}));
    when(mockRpc.sendJRpcMethod('printer.emergency_stop'))
        .thenAnswer((_) async => RpcResponse(jsonrpc: '2.0', id: 1, result: {}));
    when(mockRpc.sendJRpcMethod('machine.services.restart', params: {'service': 'klipper'}))
        .thenAnswer((_) async => RpcResponse(jsonrpc: '2.0', id: 1, result: {}));
    when(mockRpc.sendJRpcMethod('machine.services.stop', params: {'service': 'klipper'}))
        .thenAnswer((_) async => RpcResponse(jsonrpc: '2.0', id: 1, result: {}));
    when(mockRpc.sendJRpcMethod('machine.services.start', params: {'service': 'klipper'}))
        .thenAnswer((_) async => RpcResponse(jsonrpc: '2.0', id: 1, result: {}));

    final container = makeContainer(mockRpc);
    await container.read(klipperProvider(uuid).future);

    final service = container.read(klipperServiceProvider(uuid));

    service.restartMCUs();
    service.rebootHost();
    service.shutdownHost();
    service.emergencyStop();
    await service.restartKlipper();
    await service.stopService('klipper');
    await service.startService('klipper');

    verify(mockRpc.sendJRpcMethod('printer.firmware_restart')).called(1);
    verify(mockRpc.sendJRpcMethod('machine.reboot')).called(1);
    verify(mockRpc.sendJRpcMethod('machine.shutdown')).called(1);
    verify(mockRpc.sendJRpcMethod('printer.emergency_stop')).called(1);
    verify(mockRpc.sendJRpcMethod('machine.services.restart', params: {'service': 'klipper'})).called(1);
    verify(mockRpc.sendJRpcMethod('machine.services.stop', params: {'service': 'klipper'})).called(1);
    verify(mockRpc.sendJRpcMethod('machine.services.start', params: {'service': 'klipper'})).called(1);
  });

  test('provider rebuilds on invalidation (simulates reconnect)', () async {
    final mockRpc = MockJsonRpcClient();
    var callCount = 0;

    when(mockRpc.sendJRpcMethod('server.info')).thenAnswer((_) async {
      callCount++;
      return serverInfoResponse();
    });
    when(mockRpc.sendJRpcMethod('printer.info')).thenAnswer((_) async => printerInfoResponse());

    final container = makeContainer(mockRpc);
    final sub = container.listen(klipperProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(klipperProvider(uuid).future);
    expect(callCount, 1);

    container.invalidate(klipperProvider(uuid));
    await container.read(klipperProvider(uuid).future);
    expect(callCount, 2);
  });
}
