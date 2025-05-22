/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../network/moonraker_database_client.dart';
import '../../../service/misc_providers.dart';
import '../../model/moonraker_db/fcm/device_fcm_settings.dart';
import '../fcm/device_fcm_settings_repository.dart';

part 'device_fcm_settings_repository_impl.g.dart';

@riverpod
DeviceFcmSettingsRepository deviceFcmSettingsRepository(Ref ref, String machineUUID) {
  return DeviceFcmSettingsRepositoryImpl(ref, ref.watch(moonrakerDatabaseClientProvider(machineUUID)));
}

@riverpod
Future<DeviceFcmSettings?> deviceFcmSettings(Ref ref, String machineUUID) async {
  final repo = ref.watch(deviceFcmSettingsRepositoryProvider(machineUUID));

  ref.watch(signalingHelperProvider('deviceFcm$machineUUID'));

  return (await repo.get(machineUUID));
}

class DeviceFcmSettingsRepositoryImpl extends DeviceFcmSettingsRepository {
  DeviceFcmSettingsRepositoryImpl(this.ref, this._databaseService);

  final Ref ref;
  final MoonrakerDatabaseClient _databaseService;

  @override
  Future<Map<String, DeviceFcmSettings>> all() async {
    Map<String, dynamic>? json = await _databaseService.getDatabaseItem('mobileraker', key: 'fcm');

    if (json == null) return {};

    Map<String, DeviceFcmSettings> out = {};
    json.forEach((key, value) {
      if (Uuid.isValidUUID(fromString: key)) {
        out[key] = DeviceFcmSettings.fromJson(value);
      }
    });
    return out;
  }

  @override
  Future<DeviceFcmSettings?> get(String machineId) async {
    var json = await _databaseService.getDatabaseItem('mobileraker', key: 'fcm.$machineId');
    if (json == null) return null;
    return DeviceFcmSettings.fromJson(json);
  }

  @override
  Future<void> update(String machineId, DeviceFcmSettings fcmSettings) async {
    await _databaseService.addDatabaseItem(
        'mobileraker', 'fcm.$machineId', fcmSettings.copyWith(lastModified: DateTime.now()));
    ref.invalidate(signalingHelperProvider('deviceFcm$machineId'));
  }

  @override
  Future<void> delete(String machineId) async =>
      await _databaseService.deleteDatabaseItem('mobileraker', 'fcm.$machineId');

  @override
  Future<void> deleteAll() async {
    var entries = await all();

    await Future.wait(entries.keys.map((uuid) async {
      await _databaseService.deleteDatabaseItem('mobileraker', 'fcm.$uuid');
    }));
  }
}
