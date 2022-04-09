import 'stamped_entity.dart';

class TemperaturePreset extends StampedEntity {
  TemperaturePreset({
    required DateTime created,
    required DateTime lastModified,
    required this.name,
    required this.uuid,
    this.bedTemp = 60,
    this.extruderTemp = 170,
  }) : super(created, lastModified);

  String name;
  final String uuid;
  int bedTemp; // Safe values
  int extruderTemp; // Safe values

  @override
  String toString() {
    return 'TemperatureTemplate{name: $name, uuid: $uuid, bedTemp: $bedTemp, extruderTemp: $extruderTemp}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemperaturePreset &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          uuid == other.uuid &&
          bedTemp == other.bedTemp &&
          extruderTemp == other.extruderTemp;

  @override
  int get hashCode =>
      name.hashCode ^ uuid.hashCode ^ bedTemp.hashCode ^ extruderTemp.hashCode;
}
