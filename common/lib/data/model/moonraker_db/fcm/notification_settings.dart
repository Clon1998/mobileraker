/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

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

  factory NotificationSettings.fallback() => NotificationSettings(
        created: DateTime.now(),
        lastModified: DateTime.now(),
        progress: 0.25,
        states: {PrintState.error, PrintState.printing, PrintState.paused},
        androidProgressbar: true,
        etaSources: {ETADataSource.filament, ETADataSource.slicer},
      );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) => _$NotificationSettingsFromJson(json);
}
