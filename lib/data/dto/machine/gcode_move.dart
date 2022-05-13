class GCodeMove {
  double speedFactor = 0;
  double speed = 0;
  double extrudeFactor = 0;
  bool absoluteCoordinates = false;
  bool absoluteExtrude = false;
  List<double> homingOrigin = [0.0, 0.0, 0.0, 0.0];
  List<double> position = [0.0, 0.0, 0.0, 0.0];
  List<double> gcodePosition = [0.0, 0.0, 0.0, 0.0];

  int get mmSpeed {
    return (speed / 60 * speedFactor).round();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is GCodeMove &&
              runtimeType == other.runtimeType &&
              speedFactor == other.speedFactor &&
              speed == other.speed &&
              extrudeFactor == other.extrudeFactor &&
              absoluteCoordinates == other.absoluteCoordinates &&
              absoluteExtrude == other.absoluteExtrude &&
              homingOrigin == other.homingOrigin &&
              position == other.position &&
              gcodePosition == other.gcodePosition;

  @override
  int get hashCode =>
      speedFactor.hashCode ^
      speed.hashCode ^
      extrudeFactor.hashCode ^
      absoluteCoordinates.hashCode ^
      absoluteExtrude.hashCode ^
      homingOrigin.hashCode ^
      position.hashCode ^
      gcodePosition.hashCode;
}
