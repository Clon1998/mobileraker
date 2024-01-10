/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'temperature_preset.g.dart';

@HiveType(typeId: 3)
class TemperaturePreset {
  @HiveField(0)
  String name;
  @HiveField(1)
  String uuid = const Uuid().v4();
  @HiveField(2)
  int bedTemp = 60; // Safe values
  @HiveField(3)
  int extruderTemp = 170; // Safe values

  TemperaturePreset(this.name);

  @override
  String toString() {
    return 'TemperatureTemplate{name: $name, uuid: $uuid, bedTemp: $bedTemp, extruderTemp: $extruderTemp}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemperaturePreset &&
          runtimeType == other.runtimeType &&
          (identical(name, other.name) || name == other.name) &&
          (identical(uuid, other.uuid) || uuid == other.uuid) &&
          (identical(bedTemp, other.bedTemp) || bedTemp == other.bedTemp) &&
          (identical(extruderTemp, other.extruderTemp) || extruderTemp == other.extruderTemp);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        name,
        uuid,
        bedTemp,
        extruderTemp,
      );
}
