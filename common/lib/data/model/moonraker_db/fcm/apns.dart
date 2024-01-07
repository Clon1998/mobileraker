/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

import '../stamped_entity.dart';

part 'apns.g.dart';

/**
    "apns": {
    "created":"",
    "lastModified":"",
    "liveActivity": "<UUID>",
    }
 */

@JsonSerializable()
class APNs extends StampedEntity {
  APNs({
    DateTime? created,
    DateTime? lastModified,
    this.liveActivity,
  }) : super(created, lastModified ?? DateTime.now());

  String? liveActivity;

  factory APNs.fromJson(Map<String, dynamic> json) => _$APNsFromJson(json);

  Map<String, dynamic> toJson() => _$APNsToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is APNs && runtimeType == other.runtimeType && liveActivity == other.liveActivity;

  @override
  int get hashCode => super.hashCode ^ liveActivity.hashCode;

  @override
  String toString() {
    return 'APNs{liveActivity: $liveActivity}';
  }

// APNs copyWith({double? progress, Set<String>? states}) {
//   return APNs(
//     created: created,
//     progress: progress ?? this.progress,
//     states: states ?? this.states,
//   );
// }
}
