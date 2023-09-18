/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../stamped_entity.dart';
import 'notification_settings.dart';

part 'device_fcm_settings.g.dart';

/**

    "<device-fcm-token>": {
    "created":"",
    "lastModified":"",
    "machineId":"Device local MACHIN UUIDE!",
    "machineName": "V2.1111",
    "language": "en",
    "settings": {
    "progressConfig": 0.25,
    "stateConfig": ["error","printing","paused"]
    }
    }

 */

@JsonSerializable()
class DeviceFcmSettings extends StampedEntity {
  DeviceFcmSettings(
      {DateTime? created,
      DateTime? lastModified,
      required this.fcmToken,
      required this.machineName,
      this.language = 'en',
      required this.settings,
      this.snap})
      : super(created, lastModified ?? DateTime.now());

  String fcmToken;
  String machineName;
  String language;
  NotificationSettings settings;
  Map<String, dynamic>? snap;

  DeviceFcmSettings.fallback(String fcmToken, String machineName)
      : this(
          created: DateTime.now(),
          lastModified: DateTime.now(),
          fcmToken: fcmToken,
          machineName: machineName,
          settings: NotificationSettings.fallback(),
        );

  factory DeviceFcmSettings.fromJson(Map<String, dynamic> json) =>
      _$DeviceFcmSettingsFromJson(json);

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
          mapEquals(snap,other.snap);

  @override
  int get hashCode =>
      super.hashCode ^
      fcmToken.hashCode ^
      machineName.hashCode ^
      language.hashCode ^
      settings.hashCode^
      snap.hashCode;

  @override
  String toString() {
    return 'DeviceFcmSettings{machineId: $fcmToken, machineName: $machineName, language: $language, settings: $settings}';
  }
}
