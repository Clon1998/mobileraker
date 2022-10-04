import 'package:freezed_annotation/freezed_annotation.dart';

part 'motion_report.freezed.dart';


@freezed
class MotionReport with _$MotionReport {
  const factory MotionReport({
    @Default([0.0, 0.0, 0.0, 0.0]) List<double> livePosition,
    @Default(0) double liveVelocity,
    @Default(0) double liveExtruderVelocity,
  }) = _MotionReport;
}
