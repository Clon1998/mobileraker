/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

import '../stamped_entity.dart';

part 'temperature_preset.g.dart';

@JsonSerializable()
class TemperaturePreset extends StampedEntity {
  TemperaturePreset({
    DateTime? created,
    DateTime? lastModified,
    required this.name,
    String? uuid,
    this.bedTemp = 60,
    this.extruderTemp = 170,
  })  : uuid = uuid ?? const Uuid().v4(),
        super(created, lastModified ?? DateTime.now());

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
          (identical(other.name, name) || name == other.name) &&
          (identical(other.uuid, uuid) || uuid == other.uuid) &&
          (identical(other.bedTemp, bedTemp) || bedTemp == other.bedTemp) &&
          (identical(other.extruderTemp, extruderTemp) || extruderTemp == other.extruderTemp);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        name,
        uuid,
        bedTemp,
        extruderTemp,
      );
}
