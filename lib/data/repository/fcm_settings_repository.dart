import 'package:mobileraker/data/model/moonraker_db/fcm_settings.dart';

abstract class FcmSettingsRepository {
  Future<void> update(String machineId, FcmSettings fcmSettings);

  Future<FcmSettings?> get(String machineId);
}
