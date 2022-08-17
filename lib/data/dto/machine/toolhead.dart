import 'package:freezed_annotation/freezed_annotation.dart';

part 'toolhead.freezed.dart';

enum PrinterAxis { X, Y, Z, E }

@freezed
class Toolhead with _$Toolhead {
  const factory Toolhead({
    @Default(<PrinterAxis>{}) Set<PrinterAxis> homedAxes,
    @Default([0.0, 0.0, 0.0, 0.0]) List<double> position,
    @Default('extruder') String activeExtruder,
    double? printTime,
    double? estimatedPrintTime,
    @Default(500) double maxVelocity,
    @Default(3000) double maxAccel,
    @Default(3000) double maxAccelToDecel,
    @Default(1500) double squareCornerVelocity,
  }) = _Toolhead;
}
