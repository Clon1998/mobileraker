
enum PrinterAxis { X, Y, Z, E }

class Toolhead {
  Set<PrinterAxis> homedAxes = {};
  List<double> position = [0.0, 0.0, 0.0, 0.0];

  String? activeExtruder;
  double? printTime;
  double? estimatedPrintTime;
  double? maxVelocity;
  double? maxAccel;
  double? maxAccelToDecel;
  double? squareCornerVelocity;

  @override
  String toString() {
    return 'Toolhead{homedAxes: $homedAxes, position: $position, activeExtruder: $activeExtruder, printTime: $printTime, estimatedPrintTime: $estimatedPrintTime, maxVelocity: $maxVelocity, maxAccel: $maxAccel, maxAccelToDecel: $maxAccelToDecel, squareCornerVelocity: $squareCornerVelocity}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Toolhead &&
              runtimeType == other.runtimeType &&
              homedAxes == other.homedAxes &&
              position == other.position &&
              activeExtruder == other.activeExtruder &&
              printTime == other.printTime &&
              estimatedPrintTime == other.estimatedPrintTime &&
              maxVelocity == other.maxVelocity &&
              maxAccel == other.maxAccel &&
              maxAccelToDecel == other.maxAccelToDecel &&
              squareCornerVelocity == other.squareCornerVelocity;

  @override
  int get hashCode =>
      homedAxes.hashCode ^
      position.hashCode ^
      activeExtruder.hashCode ^
      printTime.hashCode ^
      estimatedPrintTime.hashCode ^
      maxVelocity.hashCode ^
      maxAccel.hashCode ^
      maxAccelToDecel.hashCode ^
      squareCornerVelocity.hashCode;
}
