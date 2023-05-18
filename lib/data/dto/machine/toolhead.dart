import 'package:enum_to_string/enum_to_string.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'toolhead.freezed.dart';
part 'toolhead.g.dart';

enum PrinterAxis { X, Y, Z, E }

Set<PrinterAxis> _homedAxisFromJson(String haxis) => haxis
    .toUpperCase()
    .split('')
    .map((e) => EnumToString.fromString(PrinterAxis.values, e)!)
    .toSet();

String _homedAxisToJson(Set<PrinterAxis> homed) =>
    homed.map((e) => e.name).join();

@freezed
class Toolhead with _$Toolhead {
  const factory Toolhead({
    @JsonKey(
        name: 'homed_axes',
        fromJson: _homedAxisFromJson,
        toJson: _homedAxisToJson)
    @Default(<PrinterAxis>{})
        Set<PrinterAxis> homedAxes,
    @Default([0.0, 0.0, 0.0, 0.0]) List<double> position,
    @JsonKey(name: 'extruder') @Default('extruder') String activeExtruder,
    @JsonKey(name: 'print_time') double? printTime,
    @JsonKey(name: 'estimated_print_time') double? estimatedPrintTime,
    @JsonKey(name: 'max_velocity') @Default(500) double maxVelocity,
    @JsonKey(name: 'max_accel') @Default(3000) double maxAccel,
    @JsonKey(name: 'max_accel_to_decel') @Default(3000) double maxAccelToDecel,
    @JsonKey(name: 'square_corner_velocity')
    @Default(1500)
        double squareCornerVelocity,
  }) = _Toolhead;

  factory Toolhead.fromJson(Map<String, dynamic> json) =>
      _$ToolheadFromJson(json);

  factory Toolhead.partialUpdate(
      Toolhead? current, Map<String, dynamic> partialJson) {
    Toolhead old = current ?? const Toolhead();
    var mergedJson = {...old.toJson(), ...partialJson};

    return Toolhead.fromJson(mergedJson);
  }
}