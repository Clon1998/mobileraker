import 'package:mobileraker/data/model/moonraker_db/device_fcm_settings.dart';

abstract class FcmSettingsRepository {
  Future<void> update(String machineId, DeviceFcmSettings fcmSettings);

  Future<DeviceFcmSettings?> get(String machineId);
}
