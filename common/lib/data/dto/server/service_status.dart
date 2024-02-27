/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'service_status.freezed.dart';
part 'service_status.g.dart';

// "klipper": {
// "active_state": "active",
// "sub_state": "running"
// },

enum ServiceState { active, deactivating, inactive, unknown }

@freezed
class ServiceStatus with _$ServiceStatus {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ServiceStatus({
    @JsonKey(includeToJson: false) required String name,
    @JsonKey(unknownEnumValue: ServiceState.unknown) required ServiceState activeState,
    required String subState,
  }) = _ServiceStatus;

  factory ServiceStatus.fromJson(Map<String, dynamic> json) => _$ServiceStatusFromJson(json);
}
