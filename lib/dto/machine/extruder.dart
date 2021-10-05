class Extruder {
  double temperature = 0;
  double target = 0;
  double pressureAdvance = 0;
  double smoothTime = 0;
  double power = 0;

  @override
  String toString() {
    return 'Extruder{temperature: $temperature, target: $target, pressureAdvance: $pressureAdvance, smoothTime: $smoothTime}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Extruder &&
              runtimeType == other.runtimeType &&
              temperature == other.temperature &&
              target == other.target &&
              pressureAdvance == other.pressureAdvance &&
              smoothTime == other.smoothTime &&
              power == other.power;

  @override
  int get hashCode =>
      temperature.hashCode ^
      target.hashCode ^
      pressureAdvance.hashCode ^
      smoothTime.hashCode ^
      power.hashCode;
}
