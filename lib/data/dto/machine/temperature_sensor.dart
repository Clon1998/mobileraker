class TemperatureSensor {
  String name;

  double temperature = 0.0;
  double measuredMinTemp = 0.0;
  double measuredMaxTemp = 0.0;

  DateTime lastHistory = DateTime(1990);
  List<double>? temperatureHistory;

  TemperatureSensor(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemperatureSensor &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          temperature == other.temperature &&
          measuredMinTemp == other.measuredMinTemp &&
          measuredMaxTemp == other.measuredMaxTemp &&
          lastHistory == other.lastHistory &&
          temperatureHistory == other.temperatureHistory;

  @override
  int get hashCode =>
      name.hashCode ^
      temperature.hashCode ^
      measuredMinTemp.hashCode ^
      measuredMaxTemp.hashCode ^
      lastHistory.hashCode ^
      temperatureHistory.hashCode;
}
