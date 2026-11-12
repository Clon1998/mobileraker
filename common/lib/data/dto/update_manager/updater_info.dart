/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'update_commit.dart';

part 'updater_info.freezed.dart';
part 'updater_info.g.dart';

/// How Moonraker's update manager updates a software (`configured_type`).
enum UpdaterType {
  /// A git repo, e.g. Klipper and Moonraker.
  @JsonValue('git_repo')
  gitRepo,

  /// A web client distributed as GitHub release, e.g. Mainsail and Fluidd.
  web,

  /// A local application distributed as GitHub release.
  zip,

  /// A python package installed in its own virtualenv.
  python,

  /// The packages of the host's package manager.
  system,

  unknown,
}

/// The state of a single software registered in Moonraker's update manager. Which fields are set depends on the
/// [configuredType], everything a type does not report keeps its default.
///
/// https://moonraker.readthedocs.io/en/latest/external_api/update_manager/#get-update-status
@freezed
sealed class UpdaterInfo with _$UpdaterInfo {
  const UpdaterInfo._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory UpdaterInfo({
    required String name,
    @JsonKey(unknownEnumValue: UpdaterType.unknown) @Default(UpdaterType.unknown) UpdaterType configuredType,
    String? channel,
    @Default('') String version,
    @Default('') String remoteVersion,
    @Default('') String rollbackVersion,
    @Default('') String fullVersionString,
    @Default('') String currentHash,
    @Default('') String remoteHash,
    String? owner,
    String? repoName,
    String? branch,
    String? remoteUrl,
    @Default(true) bool isValid,
    @Default(false) bool isDirty,
    @Default(false) bool corrupt,
    @Default(false) bool detached,
    @Default(false) bool debugEnabled,
    // When present, the updater is invalid and Moonraker refuses to update it.
    @Default([]) List<String> warnings,
    // Unexpected, but updates still work (e.g. untracked files).
    @Default([]) List<String> anomalies,
    // Output of a failed git command.
    @Default([]) List<String> gitMessages,
    // Web/zip only: the last error of the updater.
    @Default('') String lastError,
    // Limited to 30 untagged commits by Moonraker, see commitsBehindCount.
    @Default([]) List<UpdateCommit> commitsBehind,
    @Default(0) int commitsBehindCount,
    // Python only.
    @Default('') String changelogUrl,
    // System only.
    @Default(0) int packageCount,
    @Default([]) List<String> packageList,
  }) = _UpdaterInfo;

  factory UpdaterInfo.fromJson(Map<String, dynamic> json) => _$UpdaterInfoFromJson(json);
}
