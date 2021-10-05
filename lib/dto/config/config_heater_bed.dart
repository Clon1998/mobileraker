class ConfigHeaterBed {
  late final String heaterPin;
  late final String sensorType;
  late final String sensorPin;
  late final String control;
  late final double minTemp;
  late final double maxTemp;
  late final double maxPower;

  ConfigHeaterBed.parse(Map<String, dynamic> json) {
    heaterPin = json['heater_pin'];
    sensorType = json['sensor_type'];
    sensorPin = json['sensor_pin'];
    control = json['control'];
    minTemp = json['min_temp'];
    maxTemp = json['max_temp'];
    maxPower = json['max_power'];
  }
}
