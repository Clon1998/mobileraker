/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'sudo_info.freezed.dart';
part 'sudo_info.g.dart';

/*
{
  "sudo_access": null,
  "linux_user": "pi",
  "sudo_requested": false,
  "request_messages": []
}
 */

/// Whether Moonraker waits for the sudo password to continue a task, e.g. an update that has to change its systemd
/// service (`machine.sudo.info`, `notify_sudo_alert`).
///
/// https://moonraker.readthedocs.io/en/latest/external_api/machine/#get-sudo-info
@freezed
sealed class SudoInfo with _$SudoInfo {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory SudoInfo({
    /// The linux user Moonraker runs as, whose password is asked for.
    String? linuxUser,
    @Default(false) bool sudoRequested,

    /// Why the password is needed, one message per pending task.
    @Default([]) List<String> requestMessages,
  }) = _SudoInfo;

  factory SudoInfo.fromJson(Map<String, dynamic> json) => _$SudoInfoFromJson(json);
}
