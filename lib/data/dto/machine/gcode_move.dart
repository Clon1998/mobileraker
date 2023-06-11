/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'gcode_move.freezed.dart';

@freezed
class GCodeMove with _$GCodeMove {
  const GCodeMove._();

  const factory GCodeMove({
    @Default(0) double speedFactor,
    @Default(0) double speed,
    @Default(0) double extrudeFactor,
    @Default(false) bool absoluteCoordinates,
    @Default(false) bool absoluteExtrude,
    @Default([0.0, 0.0, 0.0, 0.0]) List<double> homingOrigin,
    @Default([0.0, 0.0, 0.0, 0.0]) List<double> position,
    @Default([0.0, 0.0, 0.0, 0.0]) List<double> gcodePosition,
  }) = _GCodeMove;

  int get mmSpeed {
    return (speed / 60 * speedFactor).round();
  }
}
