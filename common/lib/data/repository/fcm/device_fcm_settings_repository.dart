/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import '../../model/moonraker_db/fcm/device_fcm_settings.dart';

abstract class DeviceFcmSettingsRepository {
  Future<void> update(String machineId, DeviceFcmSettings fcmSettings);

  Future<Map<String, DeviceFcmSettings>> all();

  Future<DeviceFcmSettings?> get(String machineId);

  Future<void> delete(String machineId);

  Future<void> deleteAll();
}
