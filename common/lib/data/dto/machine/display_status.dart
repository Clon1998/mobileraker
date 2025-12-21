/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'display_status.freezed.dart';
part 'display_status.g.dart';

@freezed
class DisplayStatus with _$DisplayStatus {
  @StringDoubleConverter()
  const factory DisplayStatus({
    @Default(0) double progress,
    String? message,
  }) = _DisplayStatus;

  factory DisplayStatus.fromJson(Map<String, dynamic> json) =>
      _$DisplayStatusFromJson(json);

  factory DisplayStatus.partialUpdate(
      DisplayStatus? current, Map<String, dynamic> partialJson) {
    DisplayStatus old = current ?? const DisplayStatus();
    var mergedJson = {...old.toJson(), ...partialJson};
    return DisplayStatus.fromJson(mergedJson);
  }
}
