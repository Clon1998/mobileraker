/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'apns.dart';
import 'notification_settings.dart';

part 'device_fcm_settings.freezed.dart';
part 'device_fcm_settings.g.dart';

/**

    "<device-fcm-token>": {
    "created":"",
    "lastModified":"",
    "machineId":"Device local MACHIN UUIDE!",
    "machineName": "V2.1111",
    "language": "en",
    "version": "0.9.9-android", // or -ios
    "settings": {
    "progressConfig": 0.25,
    "stateConfig": ["error","printing","paused"]
    },
    "apns:{
    "liveActivity": "........"
    }
    }

 */

@freezed
class DeviceFcmSettings with _$DeviceFcmSettings {
  const DeviceFcmSettings._();

  @JsonSerializable(explicitToJson: true)
  const factory DeviceFcmSettings({
    DateTime? created,
    DateTime? lastModified,
    required String fcmToken,
    required String machineName,
    @Default('en') String language,
    @Default('24h') String timeFormat,
    String? version,
    required NotificationSettings settings,
    Map<String, dynamic>? snap,
    APNs? apns,
  }) = _DeviceFcmSettings;

  // Implementing the fallback factory constructor
  factory DeviceFcmSettings.fallback(String fcmToken, String machineName, String? version,
      NotificationSettings? settings) {
    final now = DateTime.now();
    return DeviceFcmSettings(
      created: now,
      lastModified: now,
      fcmToken: fcmToken,
      machineName: machineName,
      settings: settings ?? NotificationSettings.fallback(),
      version: version,
    );
  }


  factory DeviceFcmSettings.fromJson(Map<String, dynamic> json) => _$DeviceFcmSettingsFromJson(json);

  Map<String, dynamic> delta(DeviceFcmSettings other) {
    final delta = <String, dynamic>{};

    if (fcmToken != other.fcmToken) {
      delta['fcmToken'] = other.fcmToken;
    }
    if (machineName != other.machineName) {
      delta['machineName'] = other.machineName;
    }
    if (language != other.language) {
      delta['language'] = other.language;
    }
    if (timeFormat != other.timeFormat) {
      delta['timeFormat'] = other.timeFormat;
    }
    if (version != other.version) {
      delta['version'] = other.version;
    }

    // APNs and Snap are not included in the delta calculation as they are primarily used by the companion app
    final settingsDelta = settings.delta(other.settings);
    if (settingsDelta.isNotEmpty) {
      delta['settings'] = settingsDelta;
    }

    return delta;
  }

  DeviceFcmSettings applyDelta(Map<String, dynamic> delta) {
    if (delta.isEmpty) {
      return this;
    }

    return copyWith(
      lastModified: DateTime.now(),
      fcmToken: delta['fcmToken'] ?? fcmToken,
      machineName: delta['machineName'] ?? machineName,
      language: delta['language'] ?? language,
      timeFormat: delta['timeFormat'] ?? timeFormat,
      version: delta['version'] ?? version,
      settings: settings.applyDelta(delta['settings'] as Map<String, dynamic>? ?? {}),
    );
  }
}
