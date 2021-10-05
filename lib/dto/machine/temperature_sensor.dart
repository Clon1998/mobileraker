class TemperatureSensor {
  String name;

  double temperature = 0.0;
  double measuredMinTemp = 0.0;
  double measuredMaxTemp = 0.0;

  TemperatureSensor(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemperatureSensor &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          temperature == other.temperature &&
          measuredMinTemp == other.measuredMinTemp &&
          measuredMaxTemp == other.measuredMaxTemp;

  @override
  int get hashCode =>
      name.hashCode ^
      temperature.hashCode ^
      measuredMinTemp.hashCode ^
      measuredMaxTemp.hashCode;
}
