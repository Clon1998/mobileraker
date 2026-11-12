/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'updater_info.dart';

part 'update_status.freezed.dart';

/// The state of Moonraker's update manager (`machine.update.status`, `notify_update_refreshed`).
///
/// https://moonraker.readthedocs.io/en/latest/external_api/update_manager/#get-update-status
@freezed
sealed class UpdateStatus with _$UpdateStatus {
  const UpdateStatus._();

  const factory UpdateStatus({
    /// Whether an update is in progress.
    @Default(false) bool busy,

    /// The GitHub API requests Moonraker is allowed per hour, used to check for updates.
    int? githubRateLimit,
    int? githubRequestsRemaining,
    DateTime? githubLimitResetTime,

    /// The registered software, in the order Moonraker reports it.
    @Default([]) List<UpdaterInfo> updaters,
  }) = _UpdateStatus;

  factory UpdateStatus.fromJson(Map<String, dynamic> json) {
    final versionInfo = (json['version_info'] as Map?)?.cast<String, dynamic>() ?? const {};
    final resetTime = (json['github_limit_reset_time'] as num?)?.toInt();

    return UpdateStatus(
      busy: json['busy'] == true,
      githubRateLimit: (json['github_rate_limit'] as num?)?.toInt(),
      githubRequestsRemaining: (json['github_requests_remaining'] as num?)?.toInt(),
      githubLimitResetTime: resetTime == null ? null : DateTime.fromMillisecondsSinceEpoch(resetTime * 1000),
      updaters: [
        for (final MapEntry(:key, :value) in versionInfo.entries)
          if (value is Map)
            UpdaterInfo.fromJson({
              // The key is the name of the updater. `system` neither had a name nor a type on older versions.
              ...value.cast<String, dynamic>(),
              'name': key,
              if (key == 'system') 'configured_type': 'system',
            }),
      ],
    );
  }
}
