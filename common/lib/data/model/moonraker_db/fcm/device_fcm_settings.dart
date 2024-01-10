/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../stamped_entity.dart';
import 'apns.dart';
import 'notification_settings.dart';

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

@JsonSerializable()
class DeviceFcmSettings extends StampedEntity {
  DeviceFcmSettings({
    DateTime? created,
    DateTime? lastModified,
    required this.fcmToken,
    required this.machineName,
    this.language = 'en',
    required this.settings,
    this.snap,
    this.version,
  }) : super(created, lastModified ?? DateTime.now());

  String fcmToken;
  String machineName;
  String language;
  String? version;
  NotificationSettings settings;
  Map<String, dynamic>? snap;
  APNs? apns;

  DeviceFcmSettings.fallback(String fcmToken, String machineName, String? version)
      : this(
          created: DateTime.now(),
          lastModified: DateTime.now(),
          fcmToken: fcmToken,
          machineName: machineName,
          settings: NotificationSettings.fallback(),
          version: version,
        );

  factory DeviceFcmSettings.fromJson(Map<String, dynamic> json) => _$DeviceFcmSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceFcmSettingsToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is DeviceFcmSettings &&
          runtimeType == other.runtimeType &&
          fcmToken == other.fcmToken &&
          machineName == other.machineName &&
          language == other.language &&
          settings == other.settings &&
          mapEquals(snap, other.snap) &&
          apns == other.apns &&
          version == other.version;

  @override
  int get hashCode =>
      super.hashCode ^
      fcmToken.hashCode ^
      machineName.hashCode ^
      language.hashCode ^
      settings.hashCode ^
      snap.hashCode ^
      apns.hashCode ^
      version.hashCode;

  @override
  String toString() {
    return 'DeviceFcmSettings{machineId: $fcmToken, machineName: $machineName, language: $language, settings: $settings, version: $version, snap: $snap, apns: $apns}';
  }
}
