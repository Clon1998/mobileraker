class ConfigHeaterBed {
  final String heaterPin;
  final String sensorType;
  final String sensorPin;
  final String control;
  final double minTemp;
  final double maxTemp;
  final double maxPower;

  ConfigHeaterBed.parse(Map<String, dynamic> json)
      : heaterPin = json['heater_pin'],
        sensorType = json['sensor_type'],
        sensorPin = json['sensor_pin'],
        control = json['control'],
        minTemp = json['min_temp'],
        maxTemp = json['max_temp'],
        maxPower = json['max_power'];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigHeaterBed &&
          runtimeType == other.runtimeType &&
          heaterPin == other.heaterPin &&
          sensorType == other.sensorType &&
          sensorPin == other.sensorPin &&
          control == other.control &&
          minTemp == other.minTemp &&
          maxTemp == other.maxTemp &&
          maxPower == other.maxPower;

  @override
  int get hashCode =>
      heaterPin.hashCode ^
      sensorType.hashCode ^
      sensorPin.hashCode ^
      control.hashCode ^
      minTemp.hashCode ^
      maxTemp.hashCode ^
      maxPower.hashCode;

  @override
  String toString() {
    return 'ConfigHeaterBed{heaterPin: $heaterPin, sensorType: $sensorType, sensorPin: $sensorPin, control: $control, minTemp: $minTemp, maxTemp: $maxTemp, maxPower: $maxPower}';
  }
}
