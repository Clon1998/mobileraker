/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/machine/heaters/heater_mixin.dart';
import 'package:common/data/model/time_series_entry.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/printer_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/jrpc/rpc_response.dart';
import '../../data/dto/machine/temperature_sensor_mixin.dart';

part 'temperature_store_service.g.dart';

typedef TemperatureStore = Map<(ConfigFileObjectIdentifiers, String), List<TemperatureSensorSeriesEntry>>;

/// Streams temperature history for a single sensor, optionally capped to [limit] entries.
/// Rebuilds every time [TemperatureStoreManager] emits a new snapshot (once per second).
@riverpod
Stream<List<TemperatureSensorSeriesEntry>> temperatureStore(
    Ref ref, String machineUUID, ConfigFileObjectIdentifiers cIdentifier, String objectName,
    [int? limit]) async* {
  if (!ref.mounted) return;
  ref.keepAliveFor();

  final asyncStore = ref.watch(temperatureStoreManagerProvider(machineUUID));
  if (!asyncStore.hasValue) return;

  final sensorData = asyncStore.requireValue[(cIdentifier, objectName)] ?? const [];
  if (limit != null) {
    final startIndex = max(0, sensorData.length - limit - 1);
    yield sensorData.sublist(startIndex);
  } else {
    yield sensorData;
  }
}

/// Streams all temperature stores ordered by user-defined ordering.
/// Re-emits when the manager snapshot or the ordering changes.
@riverpod
Stream<TemperatureStore> temperatureStores(Ref ref, String machineUUID) async* {
  if (!ref.mounted) {
    talker.warning('[temperatureStoresProvider($machineUUID)] Ref is not mounted, cannot watch temperature stores');
    return;
  }
  ref.keepAliveFor();

  // Resolve ordering first so the subsequent sync watch is not interrupted by an async gap.
  final ordering = await ref.watch(machineSettingsProvider(machineUUID).selectAsync((s) => s.tempOrdering));

  final asyncStore = ref.watch(temperatureStoreManagerProvider(machineUUID));
  if (!asyncStore.hasValue) return;

  final stores = asyncStore.requireValue;
  final TemperatureStore ordered = {};
  for (final entry in ordering) {
    final key = (entry.kind, entry.name);
    stores[key]?.let((it) => ordered[key] = it);
  }
  for (final entry in stores.entries) {
    ordered.putIfAbsent(entry.key, () => entry.value);
  }
  yield ordered;
}

/// Owns all temperature ring-buffer state. Replaces the old TemperatureStoreService class.
/// Rebuilds on JRPC reconnect; a 1-second timer drives incremental updates via [state] mutations.
@Riverpod(keepAlive: true)
class TemperatureStoreManager extends _$TemperatureStoreManager {
  static const int maxStoreSize = 20 * 60; // 20 minutes

  final Map<(ConfigFileObjectIdentifiers, String), QueueList<TemperatureSensorSeriesEntry>> _data = {};
  Timer? _timer;
  DateTime? _pausedAt;

  JsonRpcClient get _jrpcClient => ref.read(jrpcClientProvider(machineUUID));

  @override
  Future<TemperatureStore> build(String machineUUID) async {
    _data.clear();
    _timer?.cancel();
    _timer = null;
    _pausedAt = null;

    ref.onDispose(() => _timer?.cancel());

    ref.listen(appLifecycleProvider, (_, next) {
      if (next == AppLifecycleState.paused) {
        _pauseTimer();
      } else if (next == AppLifecycleState.resumed) {
        _resumeTimer();
      }
    });

    final clientState = await ref.watch(jrpcClientStateProvider(machineUUID).future);
    if (clientState != ClientState.connected) {
      return const {};
    }

    await _fetchAndPopulate();
    _startSyncTimer();
    return _snapshot();
  }

  void _pauseTimer() {
    _timer?.cancel();
    _pausedAt = DateTime.now();
    talker.info('$_tag Pausing update timer');
  }

  void _resumeTimer() {
    if (_pausedAt == null) return;
    if (DateTime.now().difference(_pausedAt!).inSeconds >= 60) {
      talker.info('$_tag Resuming by re-fetching');
      ref.invalidateSelf();
    } else {
      talker.info('$_tag Resuming timer');
      _startSyncTimer();
    }
    _pausedAt = null;
  }

  void _startSyncTimer() {
    talker.info('$_tag Starting 1-second sync timer');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _syncFromPrinter());
  }

  void _syncFromPrinter() {
    final printer = ref.read(printerProvider(machineUUID)).value;
    if (printer == null) {
      talker.warning('$_tag Printer is null, skipping sync');
      return;
    }

    final sensors = <TemperatureSensorMixin>[
      ...printer.extruders,
      if (printer.heaterBed != null) printer.heaterBed!,
      ...printer.genericHeaters.values,
      ...printer.temperatureSensors.values,
      ...printer.temperatureFans,
      if (printer.zThermalAdjust != null) printer.zThermalAdjust!,
    ];

    final now = DateTime.now();
    for (final sensor in sensors) {
      final point = switch (sensor) {
        HeaterMixin(temperature: final t, target: final tgt, power: final p) =>
          HeaterSeriesEntry(time: now, temperature: t, target: tgt, power: p),
        TemperatureSensorMixin(temperature: final t) => TemperatureSensorSeriesEntry(time: now, temperature: t),
      };
      _addPoint(sensor.kind, sensor.name, point);
    }

    state = AsyncData(_snapshot());
  }

  void _addPoint(ConfigFileObjectIdentifiers cIdentifier, String name, TemperatureSensorSeriesEntry point) {
    final queue = _data.putIfAbsent(
      (cIdentifier, name),
      () => QueueList<TemperatureSensorSeriesEntry>(maxStoreSize),
    );
    if (queue.length >= maxStoreSize && queue.isNotEmpty) queue.removeFirst();
    queue.add(point);
  }

  Future<void> _fetchAndPopulate() async {
    talker.info('$_tag Fetching temperature store from server');
    _timer?.cancel();

    final RpcResponse response = await _jrpcClient.sendJRpcMethod('server.temperature_store');
    talker.info('$_tag Got temperature store response');

    final raw = response.result;
    final now = DateTime.now();

    for (final storeEntry in raw.entries) {
      final key = storeEntry.key;
      final data = storeEntry.value as Map<String, dynamic>;

      var (cIdentifier, objectName) = key.toKlipperObjectIdentifier();
      if (cIdentifier
          case ConfigFileObjectIdentifiers.extruder ||
              ConfigFileObjectIdentifiers.z_thermal_adjust ||
              ConfigFileObjectIdentifiers.heater_bed) {
        objectName = key;
      }

      if (cIdentifier == null) {
        talker.warning('$_tag Could not parse object identifier from key: $key');
        continue;
      }
      if (objectName == null) {
        talker.warning('$_tag Could not parse object name from key: $key');
        continue;
      }

      talker.info('$_tag Parsing store for $cIdentifier $objectName');
      _data[(cIdentifier, objectName)] = _parseServerStoreData(now, cIdentifier, data);
    }
  }

  QueueList<TemperatureSensorSeriesEntry> _parseServerStoreData(
      DateTime now, ConfigFileObjectIdentifiers cIdentifier, Map<String, dynamic> data) {
    final isHeater = cIdentifier.isHeater;

    final temperatures = (data['temperatures'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
    final targets = (data['targets'] as List<dynamic>?)?.only(isHeater)?.map((e) => (e as num).toDouble()).toList();
    final powers = (data['powers'] as List<dynamic>?)?.only(isHeater)?.map((e) => (e as num).toDouble()).toList();

    final historyLength = min(
      maxStoreSize,
      max(temperatures.length, max(targets?.length ?? 0, powers?.length ?? 0)),
    );

    talker.info('$_tag Parsing store with $historyLength entries');

    final tempOffset = max(temperatures.length - maxStoreSize, 0);
    final targetOffset = targets?.length.let((it) => max(it - maxStoreSize, 0)) ?? 0;
    final powerOffset = powers?.length.let((it) => max(it - maxStoreSize, 0)) ?? 0;

    final store = QueueList<TemperatureSensorSeriesEntry>(maxStoreSize);
    for (int i = 0; i < historyLength; i++) {
      final time = now.subtract(Duration(seconds: historyLength - i));
      final temp = temperatures.elementAtOrNull(tempOffset + i) ?? 0;
      final target = targets?.elementAtOrNull(targetOffset + i) ?? 0;
      final power = powers?.elementAtOrNull(powerOffset + i) ?? 0;
      store.add(
        isHeater
            ? HeaterSeriesEntry(time: time, temperature: temp, target: target, power: power)
            : TemperatureSensorSeriesEntry(time: time, temperature: temp),
      );
    }
    return store;
  }

  TemperatureStore _snapshot() => Map.unmodifiable({
        for (final e in _data.entries) e.key: List<TemperatureSensorSeriesEntry>.unmodifiable(e.value),
      });

  String get _tag => '[TemperatureStoreManager($machineUUID)]';
}
