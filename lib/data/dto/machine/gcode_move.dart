import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/util/extensions/double_extension.dart';

part 'gcode_move.freezed.dart';
part 'gcode_move.g.dart';

@freezed
class GCodeMove with _$GCodeMove {
  const GCodeMove._();

  const factory GCodeMove({
    @JsonKey(name: 'speed_factor', fromJson: _toTwoFractions)
    @Default(0)
        double speedFactor,
    @Default(0) double speed,
    @JsonKey(name: 'extrude_factor', fromJson: _toTwoFractions)
    @Default(0)
        double extrudeFactor,
    @JsonKey(name: 'absolute_coordinates')
    @Default(false)
        bool absoluteCoordinates,
    @JsonKey(name: 'absolute_extrude') @Default(false) bool absoluteExtrude,
    @JsonKey(name: 'homing_origin')
    @Default([0.0, 0.0, 0.0, 0.0])
        List<double> homingOrigin,
    @Default([0.0, 0.0, 0.0, 0.0]) List<double> position,
    @JsonKey(name: 'gcode_position')
    @Default([0.0, 0.0, 0.0, 0.0])
        List<double> gcodePosition,
  }) = _GCodeMove;

  factory GCodeMove.fromJson(Map<String, dynamic> json) =>
      _$GCodeMoveFromJson(json);

  factory GCodeMove.partialUpdate(
      GCodeMove? current, Map<String, dynamic> partialJson) {
    GCodeMove old = current ?? const GCodeMove();
    var mergedJson = {...old.toJson(), ...partialJson};
    return GCodeMove.fromJson(mergedJson);
  }

  int get mmSpeed {
    return (speed / 60 * speedFactor).round();
  }
}

double _toTwoFractions(double d) => d.toPrecision(2);
