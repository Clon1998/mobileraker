/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_commit.freezed.dart';
part 'update_commit.g.dart';

/*
{
  "sha": "e3cbe7ea3663a8cd10207a9aecc4e5458aeb1f1f",
  "author": "Kevin O'Connor",
  "date": "1644534721",
  "subject": "stm32: Clear SPE flag on a change to SPI CR1 register",
  "message": "The stm32 specs indicate that the SPE bit must be cleared before\nchanging the CPHA or CPOL bits.",
  "tag": null
}
 */

/// A commit a git repo is behind its remote.
@freezed
sealed class UpdateCommit with _$UpdateCommit {
  const UpdateCommit._();

  const factory UpdateCommit({
    @Default('') String sha,
    @Default('') String author,
    // Moonraker takes the unix time from the git log, as a string.
    @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson) DateTime? date,
    @Default('') String subject,
    @Default('') String message,
    String? tag,
  }) = _UpdateCommit;

  factory UpdateCommit.fromJson(Map<String, dynamic> json) => _$UpdateCommitFromJson(json);
}

DateTime? _dateFromJson(Object? raw) {
  final seconds = switch (raw) {
    num() => raw.toInt(),
    String() => int.tryParse(raw),
    _ => null,
  };
  return seconds == null ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}

String? _dateToJson(DateTime? date) => date == null ? null : '${date.millisecondsSinceEpoch ~/ 1000}';
