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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigExtruder &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          nozzleDiameter == other.nozzleDiameter &&
          maxExtrudeOnlyDistance == other.maxExtrudeOnlyDistance &&
          minTemp == other.minTemp &&
          maxTemp == other.maxTemp &&
          maxPower == other.maxPower;

  @override
  int get hashCode =>
      name.hashCode ^
      nozzleDiameter.hashCode ^
      maxExtrudeOnlyDistance.hashCode ^
      minTemp.hashCode ^
      maxTemp.hashCode ^
      maxPower.hashCode;

  @override
  String toString() {
    return 'ConfigExtruder{name: $name, nozzleDiameter: $nozzleDiameter, maxExtrudeOnlyDistance: $maxExtrudeOnlyDistance, minTemp: $minTemp, maxTemp: $maxTemp, maxPower: $maxPower}';
  }
}