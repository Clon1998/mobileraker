/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'developer_announcement_entry.dart';

part 'developer_announcements.freezed.dart';
part 'developer_announcements.g.dart';

@freezed
class DeveloperAnnouncement with _$DeveloperAnnouncement {
  const factory DeveloperAnnouncement({
    required bool enabled,
    required List<DeveloperAnnouncementEntry> messages,
  }) = _DeveloperAnnouncement;

  factory DeveloperAnnouncement.fromJson(Map<String, dynamic> json) => _$DeveloperAnnouncementFromJson(json);
}
