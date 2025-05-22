/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'apns.freezed.dart';
part 'apns.g.dart';

/**
    "apns": {
    "created":"",
    "lastModified":"",
    "liveActivity": "<UUID>",
    "pushToStart": "<APPLE-ID>"
    }
 */

@freezed
class APNs with _$APNs {
  const APNs._();

  const factory APNs({
    DateTime? created,
    DateTime? lastModified,
    String? liveActivity,
    String? pushToStart,
  }) = _APNs;

  factory APNs.fromJson(Map<String, dynamic> json) => _$APNsFromJson(json);
}
