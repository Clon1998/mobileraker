/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'motion_report.freezed.dart';
part 'motion_report.g.dart';

@freezed
class MotionReport with _$MotionReport {
  const factory MotionReport({
    @JsonKey(name: 'live_position')
    @Default([0.0, 0.0, 0.0, 0.0])
        List<double> livePosition,
    @JsonKey(name: 'live_velocity') @Default(0) double liveVelocity,
    @JsonKey(name: 'live_extruder_velocity')
    @Default(0)
        double liveExtruderVelocity,
  }) = _MotionReport;

  factory MotionReport.fromJson(Map<String, dynamic> json) =>
      _$MotionReportFromJson(json);

  factory MotionReport.partialUpdate(
      MotionReport? current, Map<String, dynamic> partialJson) {
    MotionReport old = current ?? const MotionReport();
    var mergedJson = {...old.toJson(), ...partialJson};
    return MotionReport.fromJson(mergedJson);
  }
}
