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
  factory DeviceFcmSettings.fallback(
          String fcmToken, String machineName, String? version, NotificationSettings? settings) =>
      DeviceFcmSettings(
        created: DateTime.now(),
        lastModified: DateTime.now(),
        fcmToken: fcmToken,
        machineName: machineName,
        settings: settings ?? NotificationSettings.fallback(),
        version: version,
      );

  factory DeviceFcmSettings.fromJson(Map<String, dynamic> json) => _$DeviceFcmSettingsFromJson(json);
}
