/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/enums/eta_data_source.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/dto/machine/print_state_enum.dart';

part 'setting_service.g.dart';

@Riverpod(keepAlive: true)
SettingService settingService(Ref ref) {
  return SettingService();
}

@riverpod
bool boolSetting(Ref ref, KeyValueStoreKey key, [bool fallback = false]) {
  // This is a nice way to listen to changes in the settings box.
  // However, we might want to move this logic to the Service (Well it would just move the responsibility)
  var box = Hive.box('settingsbox');
  var sub = box.watch(key: key.key).listen((event) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(settingServiceProvider).readBool(key, fallback);
}

@riverpod
String? stringSetting(Ref ref, KeyValueStoreKey key, [String? fallback]) {
  // This is a nice way to listen to changes in the settings box.
  // However, we might want to move this logic to the Service (Well it would just move the responsibility)
  var box = Hive.box('settingsbox');
  var sub = box.watch(key: key.key).listen((event) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(settingServiceProvider).readString(key, fallback);
}

@riverpod
int intSetting(Ref ref, KeyValueStoreKey key, [int fallback = 0]) {
  // This is a nice way to listen to changes in the settings box.
  // However, we might want to move this logic to the Service (Well it would just move the responsibility)
  var box = Hive.box('settingsbox');
  var sub = box.watch(key: key.key).listen((event) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(settingServiceProvider).readInt(key, fallback);
}

@riverpod
double doubleSetting(Ref ref, KeyValueStoreKey key, [double fallback = 0.0]) {
  // This is a nice way to listen to changes in the settings box.
  // However, we might want to move this logic to the Service (Well it would just move the responsibility)
  var box = Hive.box('settingsbox');
  var sub = box.watch(key: key.key).listen((event) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(settingServiceProvider).readDouble(key, fallback);
}

@riverpod
List<String> stringListSetting(Ref ref, KeyValueStoreKey key, [List<String>? fallback]) {
  // This is a nice way to listen to changes in the settings box.
  // However, we might want to move this logic to the Service (Well it would just move the responsibility)
  var box = Hive.box('settingsbox');
  var sub = box.watch(key: key.key).listen((event) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(settingServiceProvider).readList(key, fallback: fallback);
}

@riverpod
List<dynamic> listSetting(Ref ref, KeyValueStoreKey key,
    [List<dynamic>? fallback, dynamic Function(Object?)? elementDecoder]) {
  // This is a nice way to listen to changes in the settings box.
  // However, we might want to move this logic to the Service (Well it would just move the responsibility)
  var box = Hive.box('settingsbox');
  var sub = box.watch(key: key.key).listen((event) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(settingServiceProvider).readList(key, fallback: fallback, elementDecoder: elementDecoder);
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

  bool readBool(KeyValueStoreKey key, [bool? fallback]) {
    return _boxSettings.get(key.key) ?? key.defaultValue ?? fallback ?? false;
  }

  Future<void> writeInt(KeyValueStoreKey key, int val) {
    return _boxSettings.put(key.key, val);
  }

  int readInt(KeyValueStoreKey key, [int fallback = 0]) {
    return _boxSettings.get(key.key) ?? key.defaultValue ?? fallback;
  }

  Future<void> writeString(KeyValueStoreKey key, String val) {
    return _boxSettings.put(key.key, val);
  }

  String? readString(KeyValueStoreKey key, [String? fallback]) {
    return _boxSettings.get(key.key) ?? key.defaultValue ?? fallback;
  }

  Future<void> writeDouble(KeyValueStoreKey key, double val) {
    return _boxSettings.put(key.key, val);
  }

  double readDouble(KeyValueStoreKey key, [double fallback = 0.0]) {
    return _boxSettings.get(key.key) ?? key.defaultValue ?? fallback;
  }

  Future<void> write<T>(KeyValueStoreKey key, T val) {
    return _boxSettings.put(key.key, val);
  }

  T read<T>(KeyValueStoreKey key, T fallback) {
    return _boxSettings.get(key.key) ?? key.defaultValue ?? fallback;
  }

  Future<void> writeList<T>(KeyValueStoreKey key, List<T> val, [Object? Function(T)? elementEncoder]) {
    return _boxSettings.put(key.key, elementEncoder != null ? val.map(elementEncoder).toList() : val);
  }

  List<T> readList<T>(KeyValueStoreKey key, {List<T>? fallback, T Function(Object?)? elementDecoder}) {
    final readList = _boxSettings.get(key.key) as List<Object?>?;
    final output = elementDecoder != null ? readList?.map(elementDecoder).toList() : readList?.cast<T>();

    return output ?? key.defaultValue as List<T>? ?? fallback ?? [];
  }

  Future<void> writeMap<K, T>(KeyValueStoreKey key, Map<K, T> map) {
    return _boxSettings.put(key.key, map);
  }

  Map<K, T> readMap<K, T>(KeyValueStoreKey key, [Map<K, T>? fallback]) {
    return (_boxSettings.get(key.key) as Map?)?.cast<K, T>() ?? key.defaultValue as Map<K, T>? ?? fallback ?? {};
  }

  Future<void> delete(KeyValueStoreKey key) {
    return _boxSettings.delete(key.key);
  }
}

mixin KeyValueStoreKey {
  String get key;

  Object? get defaultValue;
}

enum AppSettingKeys implements KeyValueStoreKey {
  confirmEmergencyStop('ems_setting'),
  alwaysShowBabyStepping('always_babystepping_setting'),
  defaultNumEditMode('text_inpt_for_num_fields'),
  overviewIsHomescreen('start_with_overview'),
  applyOffsetsToPostion('use_offset_pos'),
  themeMode('selectedThemeMode'),
  themePack('selectedThemePack'),
  progressNotificationMode('selProgNotMode', -1),
  statesTriggeringNotification('printStateNotifications',
      [PrintState.standby, PrintState.printing, PrintState.paused, PrintState.complete, PrintState.error]),
  fullscreenCamOrientation('lcFullCam'),
  timeFormat('tMode'),
  useLiveActivity('useLiveActivity', true),
  groupSliders('groupSliders'),
  filamentSensorDialog('filamentSensorDialog'),
  receiveMarketingNotifications('receiveMarketingNotifications'),
  confirmMacroExecution('confirmMacroExecution'),
  useProgressbarNotifications('useProgressNotifications'),
  etaSources('etaCalS', [ETADataSource.slicer, ETADataSource.filament]),
  useMediumUI('useMediumUI', true),
  keepScreenOn('keepScreenOn', false),
  machineCardStyle('machineCardStyle', true), // true -> modern, false -> classic
  filterTemperatureResponse('filterTResponse', true),
  consoleShowTimestamp('cShowTs', true),
  reverseConsole('reverseConsole', false),
  hideBackupFiles('hBakFiles', false),
  showHiddenFiles('sHidFiles', false)
  ;

  @override
  final String key;

  @override
  final Object? defaultValue;

  const AppSettingKeys(this.key, [this.defaultValue]);
}

enum UtilityKeys implements KeyValueStoreKey {
  gCodeIndex('selGCodeGrp'),
  webcamIndex('selWebcamGrp'),
  fileExplorerSortCfg('selFileSrt'),
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
  machineOrdering('machineOrdering'),
  lastLocale('lastLocale', 'en'),
  fcmTokenHistory('fcmTokenHistory', <String>[]),
  graphSettings('graphSettings'),
  machineLastSeen('machineLastSeen'),
  ;

  @override
  final String key;

  @override
  final Object? defaultValue;

  const UtilityKeys(this.key, [this.defaultValue]);
}

enum UiKeys implements KeyValueStoreKey {
  hadMeshView('hMeshView'),
  hadSpoolman('hSpoolman'),
  hadWebcam('hWebcam'),
  hadPowerAPI('hPower'),
  hadFirmwareRetraction('hFwRetr'),
  hadMoreMacros('hMoreMacros'),
  hadExtruder('hExtruder'),
  ;

  @override
  final String key;

  @override
  final Object? defaultValue;

  const UiKeys(this.key, [this.defaultValue]);
}

class CompositeKey implements KeyValueStoreKey {
  CompositeKey._(this._key, [this.defaultValue]);

  final String _key;
  @override
  final Object? defaultValue;

  @override
  String get key => _key;

  factory CompositeKey.keyWithString(KeyValueStoreKey key, String str, [Object? defaultValue]) {
    return CompositeKey._('${key.key}_$str', defaultValue);
  }

  factory CompositeKey.keyWithStrings(KeyValueStoreKey key, List<String> strs, [Object? defaultValue]) {
    final str = strs.join('_');
    return CompositeKey._('${key.key}_$str', defaultValue);
  }
}
