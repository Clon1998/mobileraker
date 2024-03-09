/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'developer_announcement_entry_type.dart';

part 'developer_announcement_entry.freezed.dart';
part 'developer_announcement_entry.g.dart';

@freezed
class DeveloperAnnouncementEntry with _$DeveloperAnnouncementEntry {
  const DeveloperAnnouncementEntry._();

  const factory DeveloperAnnouncementEntry(
      {required bool show,
      required DeveloperAnnouncementEntryType type,
      required String title,
      required String body}) = _DeveloperAnnouncementEntry;

  String get hash => hashCode.toRadixString(16);

  factory DeveloperAnnouncementEntry.fromJson(Map<String, dynamic> json) => _$DeveloperAnnouncementEntryFromJson(json);
}
