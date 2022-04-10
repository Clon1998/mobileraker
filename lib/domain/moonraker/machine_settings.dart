import 'package:json_annotation/json_annotation.dart';
import 'package:mobileraker/domain/moonraker/stamped_entity.dart';

import 'macro_group.dart';
import 'temperature_preset.dart';

part 'machine_settings.g.dart';

@JsonSerializable()
class MachineSettings extends StampedEntity {
  MachineSettings(
      {required DateTime created,
      required DateTime lastModified,
      this.temperaturePresets = const [],
      this.inverts = const [false, false, false],
      this.speedXY = 100,
      this.speedZ = 30,
      this.extrudeFeedrate = 5,
      this.moveSteps = const [1, 10, 25, 50],
      this.babySteps = const [0.005, 0.01, 0.05, 0.1],
      this.extrudeSteps = const [1, 10, 25, 50],
      this.macroGroups = const []})
      : super(created, lastModified);

  MachineSettings.fallback()
      : this(created: DateTime.now(), lastModified: DateTime.now());

  List<bool> inverts; // [X,Y,Z]
  int speedXY;
  int speedZ;
  int extrudeFeedrate;
  List<int> moveSteps;
  List<double> babySteps;
  List<int> extrudeSteps;
  List<MacroGroup> macroGroups;
  List<TemperaturePreset> temperaturePresets;

  factory MachineSettings.fromJson(Map<String, dynamic> json) =>
      _$MachineSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$MachineSettingsToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is MachineSettings &&
          runtimeType == other.runtimeType &&
          inverts == other.inverts &&
          speedXY == other.speedXY &&
          speedZ == other.speedZ &&
          extrudeFeedrate == other.extrudeFeedrate &&
          moveSteps == other.moveSteps &&
          babySteps == other.babySteps &&
          extrudeSteps == other.extrudeSteps &&
          macroGroups == other.macroGroups &&
          temperaturePresets == other.temperaturePresets;

  @override
  int get hashCode =>
      super.hashCode ^
      inverts.hashCode ^
      speedXY.hashCode ^
      speedZ.hashCode ^
      extrudeFeedrate.hashCode ^
      moveSteps.hashCode ^
      babySteps.hashCode ^
      extrudeSteps.hashCode ^
      macroGroups.hashCode ^
      temperaturePresets.hashCode;

  @override
  String toString() {
    return 'MachineSettings{inverts: $inverts, speedXY: $speedXY, speedZ: $speedZ, extrudeFeedrate: $extrudeFeedrate, moveSteps: $moveSteps, babySteps: $babySteps, extrudeSteps: $extrudeSteps, macroGroups: $macroGroups, temperaturePresets: $temperaturePresets}';
  }
}
