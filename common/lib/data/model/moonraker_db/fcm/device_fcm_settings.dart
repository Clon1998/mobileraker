/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
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
    this.timeFormat = '24h',
    required this.settings,
    this.snap,
    this.version,
  }) : super(created, lastModified ?? DateTime.now());

  String fcmToken;
  String machineName;
  String language;
  String timeFormat;
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
          (identical(fcmToken, other.fcmToken) || fcmToken == other.fcmToken) &&
          (identical(machineName, other.machineName) || machineName == other.machineName) &&
          (identical(language, other.language) || language == other.language) &&
          (identical(timeFormat, other.timeFormat) || timeFormat == other.timeFormat) &&
          (identical(settings, other.settings) || settings == other.settings) &&
          const DeepCollectionEquality().equals(snap, other.snap) &&
          (identical(apns, other.apns) || apns == other.apns) &&
          (identical(version, other.version) || version == other.version);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        super.hashCode,
        fcmToken,
        machineName,
        language,
        timeFormat,
        settings,
        const DeepCollectionEquality().hash(snap),
        apns,
        version,
      );

  @override
  String toString() {
    return 'DeviceFcmSettings{machineId: $fcmToken, machineName: $machineName, language: $language, settings: $settings, version: $version, snap: $snap, apns: $apns}';
  }
}
