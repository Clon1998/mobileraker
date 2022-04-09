import 'package:hive_flutter/hive_flutter.dart';

const String emsKey = 'ems_setting';
const String showBabyAlwaysKey = 'always_babystepping_setting';
const String useTextInputForNumKey = 'text_inpt_for_num_fields';
const String startWithOverviewKey = 'start_with_overview';

/// Settings related to the App!
class SettingService {
  late final _boxSettings = Hive.box('settingsbox');

  Future<void> writeBool(String key, bool val) {
    return _boxSettings.put(key, val);
  }

  bool readBool(String key, [bool fallback = false]) {
    return _boxSettings.get(key) ?? fallback;
  }
}
