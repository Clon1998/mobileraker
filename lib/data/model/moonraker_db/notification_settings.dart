import 'package:json_annotation/json_annotation.dart';

import 'stamped_entity.dart';

part 'notification_settings.g.dart';

/**
    "settings": {
    "created":"",
    "lastModified":"",
    "progress": 0.25,
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
  }) : super(created, lastModified ?? DateTime.now());

  double progress;
  Set<String> states;

  NotificationSettings.fallback()
      : this(
          created: DateTime.now(),
          lastModified: DateTime.now(),
          progress: 0.25,
          states: const {'error', 'printing', 'paused'},
        );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationSettingsToJson(this);

  NotificationSettings copyWith({double? progress, Set<String>? states}) {
    return NotificationSettings(
      created: created,
      progress: progress ?? this.progress,
      states: states ?? this.states,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is NotificationSettings &&
          runtimeType == other.runtimeType &&
          progress == other.progress &&
          states == other.states;

  @override
  int get hashCode => super.hashCode ^ progress.hashCode ^ states.hashCode;

  @override
  String toString() {
    return 'NotificationSettings{progress: $progress, states: $states}';
  }
}
