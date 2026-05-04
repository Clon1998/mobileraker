/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/data/model/time_series_entry.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/temperature_store_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../test_utils.dart';
import 'temperature_store_manager_test.mocks.dart';

@GenerateMocks([JsonRpcClient])
void main() {
  setUpAll(() {
    setupTestLogger();
    provideDummy<RpcResponse>(RpcResponse.fromJson(jsonDecode('{"jsonrpc":"2.0","id":1,"result":{}}')));
  });

  const uuid = 'test-machine';

  RpcResponse storeResponse(Map<String, dynamic> data) =>
      RpcResponse(jsonrpc: '2.0', id: 1, result: data);

  ProviderContainer makeContainer(
    MockJsonRpcClient mockRpc, {
    ClientState clientState = ClientState.connected,
  }) {
    return ProviderContainer.test(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
      jrpcClientStateProvider(uuid).overrideWith((ref) async => clientState),
    ]);
  }

  test('returns empty map when JRPC is not connected', () async {
    final mockRpc = MockJsonRpcClient();

    final container = makeContainer(mockRpc, clientState: ClientState.disconnected);
    final store = await container.read(temperatureStoreManagerProvider(uuid).future);

    expect(store, isEmpty);
    verifyNever(mockRpc.sendJRpcMethod(any));
  });

  test('fetches temperature store on build when connected', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer((_) async => storeResponse({
          'temperature_sensor chamber': {
            'temperatures': [24.0, 25.0],
          },
        }));

    final container = makeContainer(mockRpc);
    final store = await container.read(temperatureStoreManagerProvider(uuid).future);

    expect(store, hasLength(1));
    final key = (ConfigFileObjectIdentifiers.temperature_sensor, 'chamber');
    expect(store.containsKey(key), isTrue);
    expect(store[key], hasLength(2));
    verify(mockRpc.sendJRpcMethod('server.temperature_store')).called(1);
  });

  test('parses temperature_sensor entries as TemperatureSensorSeriesEntry', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer((_) async => storeResponse({
          'temperature_sensor chamber': {
            'temperatures': [24.5, 25.0],
          },
        }));

    final container = makeContainer(mockRpc);
    final store = await container.read(temperatureStoreManagerProvider(uuid).future);

    final entries = store[(ConfigFileObjectIdentifiers.temperature_sensor, 'chamber')]!;
    expect(entries, hasLength(2));
    expect(entries.first, isA<TemperatureSensorSeriesEntry>());
    expect(entries.first, isNot(isA<HeaterSeriesEntry>()));
    expect(entries.first.temperature, 24.5);
    expect(entries.last.temperature, 25.0);
  });

  test('parses extruder entries as HeaterSeriesEntry with target and power', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer((_) async => storeResponse({
          'extruder': {
            'temperatures': [200.0, 201.0],
            'targets': [200.0, 200.0],
            'powers': [0.5, 0.4],
          },
        }));

    final container = makeContainer(mockRpc);
    final store = await container.read(temperatureStoreManagerProvider(uuid).future);

    final key = (ConfigFileObjectIdentifiers.extruder, 'extruder');
    final entries = store[key]!;
    expect(entries, hasLength(2));
    final first = entries.first as HeaterSeriesEntry;
    expect(first.temperature, 200.0);
    expect(first.target, 200.0);
    expect(first.power, 0.5);
  });

  test('parses heater_bed entries as HeaterSeriesEntry', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer((_) async => storeResponse({
          'heater_bed': {
            'temperatures': [60.0],
            'targets': [60.0],
            'powers': [0.3],
          },
        }));

    final container = makeContainer(mockRpc);
    final store = await container.read(temperatureStoreManagerProvider(uuid).future);

    final key = (ConfigFileObjectIdentifiers.heater_bed, 'heater_bed');
    final entries = store[key]!;
    expect(entries, hasLength(1));
    final entry = entries.first as HeaterSeriesEntry;
    expect(entry.temperature, 60.0);
    expect(entry.target, 60.0);
    expect(entry.power, 0.3);
  });

  test('parses heater_generic entries as HeaterSeriesEntry', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer((_) async => storeResponse({
          'heater_generic chamber_heater': {
            'temperatures': [45.0],
            'targets': [50.0],
            'powers': [0.8],
          },
        }));

    final container = makeContainer(mockRpc);
    final store = await container.read(temperatureStoreManagerProvider(uuid).future);

    final key = (ConfigFileObjectIdentifiers.heater_generic, 'chamber_heater');
    final entries = store[key]!;
    expect(entries, hasLength(1));
    expect(entries.first, isA<HeaterSeriesEntry>());
  });

  test('history longer than maxStoreSize is capped', () async {
    final mockRpc = MockJsonRpcClient();
    final maxSize = TemperatureStoreManager.maxStoreSize;
    final overflowCount = maxSize + 100;

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer((_) async => storeResponse({
          'temperature_sensor chamber': {
            'temperatures': List.generate(overflowCount, (i) => i.toDouble()),
          },
        }));

    final container = makeContainer(mockRpc);
    final store = await container.read(temperatureStoreManagerProvider(uuid).future);

    final entries = store[(ConfigFileObjectIdentifiers.temperature_sensor, 'chamber')]!;
    expect(entries.length, maxSize);
  });

  test('unknown object identifier key is skipped gracefully', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer((_) async => storeResponse({
          'totally_unknown_thing foo': {
            'temperatures': [25.0],
          },
          'temperature_sensor valid': {
            'temperatures': [30.0],
          },
        }));

    final container = makeContainer(mockRpc);
    final store = await container.read(temperatureStoreManagerProvider(uuid).future);

    // Unknown key is dropped; valid one is still parsed
    expect(store, hasLength(1));
    expect(store.containsKey((ConfigFileObjectIdentifiers.temperature_sensor, 'valid')), isTrue);
  });

  test('multiple sensors are all parsed and returned', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer((_) async => storeResponse({
          'extruder': {
            'temperatures': [200.0],
            'targets': [200.0],
            'powers': [0.5],
          },
          'heater_bed': {
            'temperatures': [60.0],
            'targets': [60.0],
            'powers': [0.2],
          },
          'temperature_sensor chamber': {
            'temperatures': [35.0],
          },
        }));

    final container = makeContainer(mockRpc);
    final store = await container.read(temperatureStoreManagerProvider(uuid).future);

    expect(store, hasLength(3));
    expect(store.containsKey((ConfigFileObjectIdentifiers.extruder, 'extruder')), isTrue);
    expect(store.containsKey((ConfigFileObjectIdentifiers.heater_bed, 'heater_bed')), isTrue);
    expect(store.containsKey((ConfigFileObjectIdentifiers.temperature_sensor, 'chamber')), isTrue);
  });

  test('assigned timestamps are monotonically increasing and end near now', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer((_) async => storeResponse({
          'temperature_sensor chamber': {
            'temperatures': [24.0, 24.5, 25.0],
          },
        }));

    final before = DateTime.now();
    final container = makeContainer(mockRpc);
    final store = await container.read(temperatureStoreManagerProvider(uuid).future);
    final after = DateTime.now();

    final entries = store[(ConfigFileObjectIdentifiers.temperature_sensor, 'chamber')]!;
    expect(entries, hasLength(3));

    // Timestamps must be strictly increasing
    for (int i = 1; i < entries.length; i++) {
      expect(entries[i].time.isAfter(entries[i - 1].time), isTrue);
    }
    // Last entry's time must be close to 'now'
    expect(entries.last.time.isAfter(before.subtract(const Duration(seconds: 5))), isTrue);
    expect(entries.last.time.isBefore(after.add(const Duration(seconds: 1))), isTrue);
  });

  test('provider rebuilds and re-fetches on invalidation', () async {
    final mockRpc = MockJsonRpcClient();
    var callCount = 0;

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer((_) async {
      callCount++;
      return storeResponse({});
    });

    final container = makeContainer(mockRpc);
    final sub = container.listen(temperatureStoreManagerProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(temperatureStoreManagerProvider(uuid).future);
    expect(callCount, 1);

    container.invalidate(temperatureStoreManagerProvider(uuid));
    await container.read(temperatureStoreManagerProvider(uuid).future);
    expect(callCount, 2);
  });
}
