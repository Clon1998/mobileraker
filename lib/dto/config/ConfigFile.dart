import 'dart:collection';

class ConfigPrinter {
  late final String kinematics;
  late final double maxVelocity;
  late final double maxAccel;
  late final double maxAccelToDecel;
  late final double squareCornerVelocity;

  ConfigPrinter.parse(Map<String, dynamic> json) {
    kinematics = json['kinematics'];
    maxVelocity = json['max_velocity'];
    maxAccel = json['max_accel'];
    maxAccelToDecel = json['max_accel_to_decel'] ?? maxAccel / 2;
    squareCornerVelocity = json['square_corner_velocity'] ?? 5;
  }
}

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

class ConfigExtruder {
  final String name;
  late final double nozzleDiameter;
  late final double maxExtrudeOnlyDistance;
  late final double minTemp;
  late final double maxTemp;
  late final double maxPower;

  ConfigExtruder.parse(this.name, Map<String, dynamic> json) {
    nozzleDiameter = json['nozzle_diameter'];
    maxExtrudeOnlyDistance = json['max_extrude_only_distance'];
    minTemp = json['min_temp'];
    maxTemp = json['max_temp'];
    maxPower = json['max_power'];
  }
}

//TODO Decide regarding null values or not!
class ConfigFile {
  ConfigPrinter? configPrinter;
  ConfigHeaterBed? configHeaterBed;
  Map<String, ConfigExtruder> extruders = HashMap();

  ConfigFile();

  ConfigFile.parse(this.rawConfig) {
    if (rawConfig.containsKey('printer'))
      configPrinter = ConfigPrinter.parse(rawConfig['printer']);
    if (rawConfig.containsKey('heater_bed'))
      configHeaterBed = ConfigHeaterBed.parse(rawConfig['heater_bed']);

    this.rawConfig.keys.forEach((key) {
      if (key.startsWith('extruder')) {
        Map<String, dynamic> jsonChild = Map.of(rawConfig[key]);
        if (jsonChild.containsKey('shared_heater')) {
          String sharedHeater = jsonChild['shared_heater'];
          Map<String, dynamic> sharedHeaterConfig =
              Map.of(rawConfig[sharedHeater]);
          sharedHeaterConfig
              .removeWhere((key, value) => jsonChild.containsKey(key));
          jsonChild.addAll(sharedHeaterConfig);
        }
        extruders[key] = ConfigExtruder.parse(key, jsonChild);
      }
    });

    //ToDo parse the config for e.g. EXTRUDERS (Temp settings), ...
  }

  Map<String, dynamic> rawConfig = {};

  bool saveConfigPending = false;

  bool get hasQuadGantry => rawConfig.containsKey('quad_gantry_level');

  bool get hasBedMesh => rawConfig.containsKey('bed_mesh');

  ConfigExtruder? get primaryExtruder => extruders['extruder'];
}
