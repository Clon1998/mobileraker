import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setting_service.g.dart';

const String emsKey = 'ems_setting';
const String showBabyAlwaysKey = 'always_babystepping_setting';
const String useTextInputForNumKey = 'text_inpt_for_num_fields';
const String startWithOverviewKey = 'start_with_overview';
const String useOffsetPosKey = 'use_offset_pos';
const String selectedThemeModeKey = 'selectedThemeMode';
const String selectedThemePackKey = 'selectedThemePack';
const String selectedGCodeGrpIndex = 'selGCodeGrp';
const String selectedWebcamGrpIndex = 'selWebcamGrp';
const String selectedProgressNotifyMode = 'selProgNotMode';
const String activeStateNotifyMode = 'activeStateNotMode';
const String requestedNotifyPermission = 'reqNotifyPerm';
const String selectedFileSortKey = 'selFileSrt';
const String recentColorsKey = 'selectedColors';

@riverpod
SettingService settingService(SettingServiceRef ref) {
  return SettingService();
}

/// Settings related to the App!
class SettingService {
  late final _boxSettings =
      Hive.box('settingsbox'); // maybe move it to the repo ?

  Future<void> writeBool(String key, bool val) {
    return _boxSettings.put(key, val);
  }

  bool readBool(String key, [bool fallback = false]) {
    return _boxSettings.get(key) ?? fallback;
  }

  Future<void> writeInt(String key, int val) {
    return _boxSettings.put(key, val);
  }

  int readInt(String key, [int fallback = 0]) {
    return _boxSettings.get(key) ?? fallback;
  }

  Future<void> write<T>(String key, T val) {
    return _boxSettings.put(key, val);
  }

  T read<T>(String key, T fallback) {
    return _boxSettings.get(key) ?? fallback;
  }

  Future<void> writeList<T>(String key, List<T> val) {
    return _boxSettings.put(key, val);
  }

  List<T> readList<T>(String key, [List<T>? fallback]) {
    return (_boxSettings.get(key) as List<dynamic>?)?.cast<T>() ??
        fallback ??
        [];
  }
}
