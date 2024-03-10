/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setting_service.g.dart';

@Riverpod(keepAlive: true)
SettingService settingService(SettingServiceRef ref) {
  return SettingService();
}

@riverpod
bool boolSetting(BoolSettingRef ref, KeyValueStoreKey key, [bool fallback = false]) {
  // This is a nice way to listen to changes in the settings box.
  // However, we might want to move this logic to the Service (Well it would just move the responsibility)
  var box = Hive.box('settingsbox');
  var sub = box.watch(key: key.key).listen((event) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(settingServiceProvider).readBool(key, fallback);
}

@riverpod
int intSetting(IntSettingRef ref, KeyValueStoreKey key, [int fallback = 0]) {
  // This is a nice way to listen to changes in the settings box.
  // However, we might want to move this logic to the Service (Well it would just move the responsibility)
  var box = Hive.box('settingsbox');
  var sub = box.watch(key: key.key).listen((event) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(settingServiceProvider).readInt(key, fallback);
}

@riverpod
Type objectSetting<Type>(ObjectSettingRef ref, KeyValueStoreKey key, Type fallback) {
  // This is a nice way to listen to changes in the settings box.
  // However, we might want to move this logic to the Service (Well it would just move the responsibility)
  var box = Hive.box('settingsbox');
  var sub = box.watch(key: key.key).listen((event) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(settingServiceProvider).read(key, fallback);
}

/// Actually this class turned more into a KeyValue store than just storing app setings
/// Settings related to the App!
class SettingService {
  late final _boxSettings = Hive.box('settingsbox'); // maybe move it to the repo ?

  bool containsKey(KeyValueStoreKey key) {
    return _boxSettings.containsKey(key.key);
  }

  Future<void> writeBool(KeyValueStoreKey key, bool val) {
    return _boxSettings.put(key.key, val);
  }

  bool readBool(KeyValueStoreKey key, [bool fallback = false]) {
    return _boxSettings.get(key.key) ?? fallback;
  }

  Future<void> writeInt(KeyValueStoreKey key, int val) {
    return _boxSettings.put(key.key, val);
  }

  int readInt(KeyValueStoreKey key, [int fallback = 0]) {
    return _boxSettings.get(key.key) ?? fallback;
  }

  Future<void> write<T>(KeyValueStoreKey key, T val) {
    return _boxSettings.put(key.key, val);
  }

  T read<T>(KeyValueStoreKey key, T fallback) {
    return _boxSettings.get(key.key) ?? fallback;
  }

  Future<void> writeList<T>(KeyValueStoreKey key, List<T> val) {
    return _boxSettings.put(key.key, val);
  }

  List<T> readList<T>(KeyValueStoreKey key, [List<T>? fallback]) {
    return (_boxSettings.get(key.key) as List<dynamic>?)?.cast<T>() ?? fallback ?? [];
  }

  Future<void> writeMap<K, T>(KeyValueStoreKey key, Map<K, T> map) {
    return _boxSettings.put(key.key, map);
  }

  Map<K, T> readMap<K, T>(KeyValueStoreKey key, [Map<K, T>? fallback]) {
    return (_boxSettings.get(key.key) as Map?)?.cast<K, T>() ?? fallback ?? {};
  }

  Future<void> delete(KeyValueStoreKey key) {
    return _boxSettings.delete(key.key);
  }
}

mixin KeyValueStoreKey {
  String get key;
}

enum AppSettingKeys implements KeyValueStoreKey {
  confirmEmergencyStop('ems_setting'),
  alwaysShowBabyStepping('always_babystepping_setting'),
  defaultNumEditMode('text_inpt_for_num_fields'),
  overviewIsHomescreen('start_with_overview'),
  applyOffsetsToPostion('use_offset_pos'),
  themeMode('selectedThemeMode'),
  themePack('selectedThemePack'),
  progressNotificationMode('selProgNotMode'),
  statesTriggeringNotification('activeStateNotMode'),
  fullscreenCamOrientation('lcFullCam'),
  timeFormat('tMode'),
  useLiveActivity('useLiveActivity'),
  groupSliders('groupSliders'),
  ;

  @override
  final String key;

  const AppSettingKeys(this.key);
}

enum UtilityKeys implements KeyValueStoreKey {
  gCodeIndex('selGCodeGrp'),
  webcamIndex('selWebcamGrp'),
  fileSortingIndex('selFileSrt'),
  requestedNotifyPermission('reqNotifyPerm'),
  recentColors('selectedColors'),
  nonSupporterDismiss('nSWDismiss'),
  nonSupporterMachineCleanup('nSMachCleanDate'),
  supporterTokenDate('supTknDate'),
  liveActivityStore('liveActivityStore'),
  zOffsetStepIndex('zOffsetStepIndex'),
  moveStepIndex('moveStepIndex'),
  extruderStepIndex('extruderStepIndex'),
  meshViewMode('meshViewMode'),
  devAnnouncementDismiss('devAnnouncementDismiss'),
  ;

  @override
  final String key;

  const UtilityKeys(this.key);
}

enum UiKeys implements KeyValueStoreKey {
  hadMeshView('hMeshView'),
  hadSpoolman('hSpoolman'),
  hadWebcam('hWebcam'),
  hadPowerAPI('hPower'),
  hadFirmwareRetraction('hFwRetr'),
  ;

  @override
  final String key;

  const UiKeys(this.key);
}

class CompositeKey implements KeyValueStoreKey {
  CompositeKey._(this._key);

  final String _key;

  @override
  String get key => _key;

  factory CompositeKey.keyWithString(KeyValueStoreKey key, String str) {
    return CompositeKey._("${key.key}_$str");
  }
}
