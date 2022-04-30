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