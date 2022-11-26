import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/notification_settings.dart';
import 'package:mobileraker/util/extensions/iterable_extension.dart';

import 'macro_group.dart';
import 'stamped_entity.dart';
import 'temperature_preset.dart';

part 'fcm_settings.g.dart';

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
class FcmSettings extends StampedEntity {
  FcmSettings(
      {DateTime? created,
      DateTime? lastModified,
      required this.fcmToken,
      required this.machineName,
      this.language = 'en',
      required this.settings})
      : super(created, lastModified ?? DateTime.now());

  String fcmToken;
  String machineName;
  String language;
  NotificationSettings settings;

  FcmSettings.fallback(String fcmToken, String machineName)
      : this(
          created: DateTime.now(),
          lastModified: DateTime.now(),
          fcmToken: fcmToken,
          machineName: machineName,
          settings: NotificationSettings.fallback(),
        );

  factory FcmSettings.fromJson(Map<String, dynamic> json) =>
      _$FcmSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$FcmSettingsToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is FcmSettings &&
          runtimeType == other.runtimeType &&
          fcmToken == other.fcmToken &&
          machineName == other.machineName &&
          language == other.language &&
          settings == other.settings;

  @override
  int get hashCode =>
      super.hashCode ^
      fcmToken.hashCode ^
      machineName.hashCode ^
      language.hashCode ^
      settings.hashCode;

  @override
  String toString() {
    return 'FcmSettings{machineId: $fcmToken, machineName: $machineName, language: $language, settings: $settings}';
  }
}
