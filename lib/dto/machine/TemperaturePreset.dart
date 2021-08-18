import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'TemperaturePreset.g.dart';

@HiveType(typeId: 3)
class TemperaturePreset {
  @HiveField(0)
  String name;
  @HiveField(1)
  String uuid = Uuid().v4();
  @HiveField(2)
  int bedTemp = 60; // Safe values
  @HiveField(3)
  int extruderTemp = 170; // Safe values

  TemperaturePreset(this.name);

  @override
  String toString() {
    return 'TemperatureTemplate{name: $name, uuid: $uuid, bedTemp: $bedTemp, extruderTemp: $extruderTemp}';
  }
}
