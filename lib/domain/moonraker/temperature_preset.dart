import 'package:json_annotation/json_annotation.dart';

import 'stamped_entity.dart';

part 'temperature_preset.g.dart';

@JsonSerializable()
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

  factory TemperaturePreset.fromJson(Map<String, dynamic> json) => _$TemperaturePresetFromJson(json);

  Map<String, dynamic> toJson() => _$TemperaturePresetToJson(this);
  
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
