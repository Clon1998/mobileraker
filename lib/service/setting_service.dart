import 'package:hive_flutter/hive_flutter.dart';

class SettingService {
  late final _boxSettings = Hive.box('settingsbox');

  SettingService();

  Future<void> writeBool(String key, bool val) {
    return _boxSettings.put(key, val);
  }

  bool readBool(String key, [bool fallback = false]) {
    return _boxSettings.get(key) ?? fallback;
  }
}
