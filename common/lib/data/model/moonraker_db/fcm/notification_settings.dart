/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

import '../stamped_entity.dart';

part 'notification_settings.g.dart';

/**
    "settings": {
    "created":"",
    "lastModified":"",
    "progress": 0.25,
    "android_progressbar": true,
    "states": ["error","printing","paused"]
    }
 */

@JsonSerializable()
class NotificationSettings extends StampedEntity {
  NotificationSettings({
    DateTime? created,
    DateTime? lastModified,
    required this.progress,
    required this.states,
    this.androidProgressbar = true,
  }) : super(created, lastModified ?? DateTime.now());

  double progress;
  Set<String> states;
  bool androidProgressbar;

  NotificationSettings.fallback()
      : this(
          created: DateTime.now(),
          lastModified: DateTime.now(),
          progress: 0.25,
          states: const {'error', 'printing', 'paused'},
          androidProgressbar: true,
        );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationSettingsToJson(this);

  NotificationSettings copyWith({double? progress, Set<String>? states, bool? androidProgressbar}) {
    return NotificationSettings(
      created: created,
      progress: progress ?? this.progress,
      states: states ?? this.states,
      androidProgressbar: androidProgressbar ?? this.androidProgressbar,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is NotificationSettings &&
          runtimeType == other.runtimeType &&
          progress == other.progress &&
          androidProgressbar == other.androidProgressbar &&
          const DeepCollectionEquality().equals(states, other.states);

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        progress,
        androidProgressbar,
        const DeepCollectionEquality().hash(states),
      ]);

  @override
  String toString() {
    return 'NotificationSettings{progress: $progress, states: $states, androidProgressbar: $androidProgressbar, created: $created, lastModified: $lastModified}';
  }
}
