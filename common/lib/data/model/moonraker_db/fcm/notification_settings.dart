/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/progress_notification_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../dto/machine/print_state_enum.dart';
import '../../../enums/eta_data_source.dart';

part 'notification_settings.freezed.dart';
part 'notification_settings.g.dart';

/**
    "settings": {
    "created":"",
    "lastModified":"",
    "progress": 0.25,
    "androidProgressbar": true,
    "states": ["error","printing","paused"],
    "webcamUUID": "UUID"
    }
 */

@freezed
class NotificationSettings with _$NotificationSettings {
  const NotificationSettings._();

  @JsonSerializable(explicitToJson: true)
  const factory NotificationSettings({
    DateTime? created,
    DateTime? lastModified,
    // Whether the notification uses global default settings instead of device-specific settings.
    // Used by the app to determine which device settings to update if the global defaults are used
    @Default(true) bool inheritGlobalSettings,
    // The interval to send notifications
    required double progress,
    // The states to send notifications for
    required Set<PrintState> states,
    // Whether to use the Android progress bar
    @Default(true) bool androidProgressbar,
    // The ETA sources to use for the progress bar
    @Default({}) Set<ETADataSource> etaSources,
    // The UUID of the webcam to use for snapshots
    String? snapshotWebcam,
    // The filament sensors to exclude from notifications
    @Default({}) Set<String> excludeFilamentSensors,
  }) = _NotificationSettings;

  factory NotificationSettings.fallback() {
    final now = DateTime.now();
    return NotificationSettings(
      created: now,
      lastModified: now,
      progress: ProgressNotificationMode.TWENTY_FIVE.value,
      states: {PrintState.error, PrintState.printing, PrintState.paused},
      androidProgressbar: true,
      etaSources: {ETADataSource.filament, ETADataSource.slicer},
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) => _$NotificationSettingsFromJson(json);

  Map<String, dynamic> delta(NotificationSettings other) {
    // Delta ignores:
    // - created
    // - lastModified
    // - inheritGlobalSettings
    // - snapshotWebcam
    // - excludeFilamentSensors

    final Map<String, dynamic> delta = {};

    if (progress != other.progress) {
      delta['progress'] = other.progress;
    }

    if (!DeepCollectionEquality.unordered().equals(states, other.states)) {
      delta['states'] = other.states;
    }

    if (!DeepCollectionEquality.unordered().equals(etaSources, other.etaSources)) {
      delta['etaSources'] = other.etaSources;
    }

    if (androidProgressbar != other.androidProgressbar) {
      delta['androidProgressbar'] = other.androidProgressbar;
    }

    return delta;
  }

  NotificationSettings applyDelta(Map<String, dynamic> delta) {
    if (delta.isEmpty) {
      return this;
    }

    return copyWith(
      lastModified: DateTime.now(),
      progress: delta['progress'] ?? progress,
      states: (delta['states'] as Set<PrintState>?) ?? states,
      etaSources: (delta['etaSources'] as Set<ETADataSource>?) ?? etaSources,
      androidProgressbar: delta['androidProgressbar'] ?? androidProgressbar,
    );
  }
}
