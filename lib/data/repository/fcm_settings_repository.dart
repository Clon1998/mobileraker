import 'package:mobileraker/data/model/moonraker_db/device_fcm_settings.dart';

abstract class FcmSettingsRepository {
  Future<void> update(String machineId, DeviceFcmSettings fcmSettings);

  Future<Map<String, DeviceFcmSettings>> all();

  Future<DeviceFcmSettings?> get(String machineId);

  Future<void> delete(String machineId);
}
