class HeaterBed {
  double temperature = 0;
  double target = 0;
  double power = 0;

  @override
  String toString() {
    return 'HeaterBed{temperature: $temperature, target: $target}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HeaterBed &&
              runtimeType == other.runtimeType &&
              temperature == other.temperature &&
              target == other.target &&
              power == other.power;

  @override
  int get hashCode => temperature.hashCode ^ target.hashCode ^ power.hashCode;
}