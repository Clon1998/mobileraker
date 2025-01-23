/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
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
import 'package:common/service/misc_providers.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/printer_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/jrpc/rpc_response.dart';
import '../../data/dto/machine/temperature_sensor_mixin.dart';

part 'temperature_store_service.g.dart';

@riverpod
Stream<List<TemperatureSensorSeriesEntry>> temperatureStore(
    Ref ref, String machineUUID, ConfigFileObjectIdentifiers cIdentifier, String objectName,
    [int? limit]) async* {
  ref.keepAliveFor();

  if (limit != null) {
    yield await ref.watch(temperatureStoreProvider(machineUUID, cIdentifier, objectName).selectAsync((store) {
      int startIndex = max(0, store.length - limit - 1);
      return store.sublist(startIndex);
    }));
  } else {
    final tempStore = ref.watch(temperatureStoreServiceProvider(machineUUID));
    yield* tempStore.getStoreStream(cIdentifier, objectName);
  }
}

@riverpod
Stream<Map<(ConfigFileObjectIdentifiers, String), List<TemperatureSensorSeriesEntry>>> temperatureStores(
    Ref ref, String machineUUID) {
  ref.keepAliveFor();

  final tempStore = ref.watch(temperatureStoreServiceProvider(machineUUID));
  return tempStore.allStores;
}

@riverpod
TemperatureStoreService temperatureStoreService(Ref ref, String machineUUID) {
  ref.keepAlive();
  final printerService = ref.watch(printerServiceProvider(machineUUID));

  final jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));

  final tempStore = TemperatureStoreService(machineUUID, printerService, jsonRpcClient);

  ref.onDispose(tempStore.dispose);

  //TODO: Maybe link this to the printer provider????
  ref.listen(
    jrpcClientStateProvider(machineUUID),
    (previous, next) {
      switch (next.valueOrNull) {
        case ClientState.connected:
          tempStore.initStores();
          break;
        case ClientState.error || ClientState.disconnected when previous?.valueOrNull == ClientState.connected:
          // TODO: Lets see if we want to do it like that but thats how we can "Reset it" if we dont want to do it with an external signal...
          //ref.invalidate(signalingHelperProvider('temperatureStore-$machineUUID'));

          ref.invalidateSelf();
          break;
        default:
      }
    },
    fireImmediately: true,
  );

  ref.listen(appLifecycleProvider, (previous, next) {
    if (next == AppLifecycleState.paused) {
      tempStore.pauseTimer();
    } else if (next == AppLifecycleState.resumed) {
      tempStore.resumeTimer();
    }
  });

  //TODO: Maby add a pause via tha appLifecycleStateProvider
  return tempStore;
}

class TemperatureStoreService {
  /// The maximum number of data points to store in the store
  static int maxStoreSize = 20 * 60; // 20 minutes

  TemperatureStoreService(this.machineUUID, this._printerService, this._jsonRpcClient);

  final String machineUUID;

  final PrinterService _printerService;

  final JsonRpcClient _jsonRpcClient;

  final Map<(ConfigFileObjectIdentifiers, String), QueueList<TemperatureSensorSeriesEntry>> _temperatureData = {};

  final Map<(ConfigFileObjectIdentifiers, String), StreamController<List<TemperatureSensorSeriesEntry>>>
      _temperatureDataControllers = {};

  /// The master controller that will emit the whole store
  final StreamController<Map<(ConfigFileObjectIdentifiers, String), List<TemperatureSensorSeriesEntry>>>
      _allStoresController = StreamController.broadcast();

  Timer? _temperatureStoreUpdateTimer;

  bool _disposed = false;

  DateTime? _pausedAt;

  QueueList<TemperatureSensorSeriesEntry> _getStore(ConfigFileObjectIdentifiers cIdentifier, String name) =>
      _temperatureData.putIfAbsent((cIdentifier, name), () => QueueList<TemperatureSensorSeriesEntry>(maxStoreSize));

  StreamController<List<TemperatureSensorSeriesEntry>> _getStoreStreamController(
          ConfigFileObjectIdentifiers cIdentifier, String name) =>
      _temperatureDataControllers
          .putIfAbsent((cIdentifier, name), () => StreamController<List<TemperatureSensorSeriesEntry>>.broadcast());

  Stream<List<TemperatureSensorSeriesEntry>> getStoreStream(ConfigFileObjectIdentifiers cIdentifier, String name) =>
      _getStoreStreamController(cIdentifier, name).stream;

  Stream<Map<(ConfigFileObjectIdentifiers, String), List<TemperatureSensorSeriesEntry>>> get allStores =>
      _allStoresController.stream;

  void _addPointToStream(ConfigFileObjectIdentifiers cIdentifier, String name, TemperatureSensorSeriesEntry point) {
    final storeForKey = _getStore(cIdentifier, name);

    if (storeForKey.length >= maxStoreSize && storeForKey.isNotEmpty) {
      storeForKey.removeFirst();
    }

    storeForKey.add(point);
    final controller = _getStoreStreamController(cIdentifier, name);
    // Using .toList() to have a new copy that can not effect the original list
    controller.add(List.unmodifiable(storeForKey));
  }

  void initStores() async {
    try {
      logger.i(
          '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Initializing temperature stores');
      await _fetchTemperatureStore();
      _startSyncTimer();
      logger.i(
          '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Initialized temperature stores');
    } catch (e, s) {
      logger.e(
          '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Error initializing temperature stores',
          e,
          s);
    }
  }

  void pauseTimer() {
    _temperatureStoreUpdateTimer?.cancel();
    _pausedAt = DateTime.now();
    logger.i(
        '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Pausing TemperatureStore update timer');
  }

  void resumeTimer() {
    // We dont want to resume if we are not paused
    if (_pausedAt == null) return;

    if (DateTime.now().difference(_pausedAt!).inSeconds >= 60) {
      logger.i(
          '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Resuming TemperatureStore update timer by fetching new data');
      initStores();
    } else {
      logger.i(
          '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Resuming TemperatureStore update timer by starting timer');
      _startSyncTimer();
    }

    _pausedAt = null;
  }

  Future<void> _fetchTemperatureStore() async {
    if (_disposed) return;
    logger.i(
        '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Fetching temperature store... stopping timer');
    _temperatureStoreUpdateTimer?.cancel();
    try {
      RpcResponse blockingResponse = await _jsonRpcClient.sendJRpcMethod('server.temperature_store');
      logger.i(
          '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Got temperature store response');
      Map<String, dynamic> raw = blockingResponse.result;
      final now = DateTime.now();

      for (var storeData in raw.entries) {
        final key = storeData.key;
        final data = storeData.value as Map<String, dynamic>;

        var (cIdentifier, objectName) = key.toKlipperObjectIdentifier();
        if (cIdentifier
            case ConfigFileObjectIdentifiers.extruder ||
                ConfigFileObjectIdentifiers.z_thermal_adjust ||
                ConfigFileObjectIdentifiers.heater_bed) {
          objectName = key;
        }

        if (cIdentifier == null) {
          logger.w(
              '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Could not parse object identifier from key: $key');
          //TODO: Add error reporting to firebase crashlytics
          continue;
        }
        if (objectName == null) {
          logger.w(
              '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Could not parse object name from key: $key');
          //TODO: Add error reporting to firebase crashlytics
          continue;
        }

        logger.i(
            '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Parsing temperature store for $cIdentifier $objectName');
        final readStore = _parseServerStoreData(now, cIdentifier, data);
        final storeKey = (cIdentifier, objectName);
        _temperatureData[storeKey] = readStore;
        final controller = _getStoreStreamController(storeKey.$1, storeKey.$2);
        controller.add(List.unmodifiable(readStore));
      }
      _allStoresController.add(Map.unmodifiable(_temperatureData));
    } catch (e, st) {
      logger.e(
          '[TemperatureStoreService($machineUUID, ${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Error fetching temperature store',
          e,
          st);
    }
  }

  QueueList<TemperatureSensorSeriesEntry> _parseServerStoreData(
      DateTime now, ConfigFileObjectIdentifiers cIdentifier, Map<String, dynamic> data) {
    final bool isHeater = {
      ConfigFileObjectIdentifiers.extruder,
      ConfigFileObjectIdentifiers.heater_generic,
      ConfigFileObjectIdentifiers.heater_bed,
    }.contains(cIdentifier);

    final temperatureHistory = (data['temperatures'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
    final List<double>? targetHistory =
        (data['target'] as List<dynamic>?)?.only(isHeater)?.map((e) => (e as num).toDouble()).toList();
    final List<double>? powerHistory =
        (data['power'] as List<dynamic>?)?.only(isHeater)?.map((e) => (e as num).toDouble()).toList();

    final int historyLength =
        min(maxStoreSize, max(temperatureHistory.length, max(targetHistory?.length ?? 0, powerHistory?.length ?? 0)));

    logger.i(
        '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Parsing temperature store with length: $historyLength');

    // If we assume maxStoreSize is smaller than any history, we only take the last maxStoreSize elements from each list

    int tempOffset = max(temperatureHistory.length - maxStoreSize, 0);
    int? targetOffset = targetHistory?.length.let((it) => max(it - maxStoreSize, 0)) ?? 0;
    int? powerOffset = powerHistory?.length.let((it) => max(it - maxStoreSize, 0)) ?? 0;

    final store = QueueList<TemperatureSensorSeriesEntry>(maxStoreSize);
    for (int i = 0; i < historyLength; i++) {
      final time = now.subtract(Duration(seconds: historyLength - i));

      final temp = temperatureHistory.elementAtOrNull(tempOffset + i) ?? 0;
      final target = targetHistory?.elementAtOrNull(targetOffset + i) ?? 0;
      final power = powerHistory?.elementAtOrNull(powerOffset + i) ?? 0;
      final point = isHeater
          ? HeaterSeriesEntry(time: time, temperature: temp, target: target, power: power)
          : TemperatureSensorSeriesEntry(time: time, temperature: temp);
      store.add(point);
    }
    return store;
  }

  void _startSyncTimer() {
    logger.i(
        '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Starting TemperatureStore update timer');
    _temperatureStoreUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateStores());
  }

  void _updateStores() {
    var printer = _printerService.currentOrNull;
    if (printer == null) {
      logger.w(
          '[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Printer is null, cannot update stores');
      return;
    }

    List<TemperatureSensorMixin> sensors = [
      ...printer.extruders,
      if (printer.heaterBed != null) printer.heaterBed!,
      ...printer.genericHeaters.values,
      ...printer.temperatureSensors.values,
      ...printer.temperatureFans,
      if (printer.zThermalAdjust != null) printer.zThermalAdjust!,
    ];

    final now = DateTime.now();
    for (var sensor in sensors) {
      // logger.i('[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Updating store for sensor: $key');
      final newPoint = switch (sensor) {
        HeaterMixin(temperature: final temp, target: final target, power: final power) =>
          HeaterSeriesEntry(time: now, temperature: temp, target: target, power: power),
        TemperatureSensorMixin(temperature: final temp) => TemperatureSensorSeriesEntry(time: now, temperature: temp),
        _ => throw UnimplementedError('Unknown sensor type: $sensor'),
      };

      _addPointToStream(sensor.kind, sensor.name, newPoint);
    }
    _allStoresController.add(Map.unmodifiable(_temperatureData));

    // var allKeys = _temperatureData.keys;
    // logger.i('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
    // for (var value in allKeys) {
    //   logger.i('\t\t$value');
    // }

    // logger.i('[TemperatureStoreService($machineUUID${_jsonRpcClient.clientType}@${_jsonRpcClient.uri.obfuscate()}})] Updated all stores with timestamp: $now');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _temperatureStoreUpdateTimer?.cancel();
    _allStoresController.close();
    _temperatureDataControllers.forEach((key, controller) => controller.close());
  }
}
