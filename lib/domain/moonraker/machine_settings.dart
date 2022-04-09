
import 'package:mobileraker/domain/moonraker/stamped_entity.dart';

import 'macro_group.dart';
import 'temperature_preset.dart';

class MachineSettings extends StampedEntity {
  MachineSettings({
    required DateTime created,
    required DateTime lastModified,
    this.temperaturePresets = const [],
    this.inverts = const [false, false, false],
    this.speedXY = 100,
    this.speedZ = 30,
    this.extrudeFeedrate = 5,
    this.moveSteps = const [1, 10, 25, 50],
    this.babySteps = const [0.005, 0.01, 0.05, 0.1],
    this.extrudeSteps = const [1, 10, 25, 50],
    List<MacroGroup>? macroGroups,
  }) : super(created, lastModified);

  // {
  //   //TODO: Remove this section once more ppl. used this version
  //   if (macroGroups != null) {
  //     this.macroGroups = macroGroups;
  //   } else {
  //     this.macroGroups = [MacroGroup(name: 'Default')];
  //   }
  // }




  List<TemperaturePreset> temperaturePresets;

  List<bool> inverts; // [X,Y,Z]
  int speedXY;
  int speedZ;
  int extrudeFeedrate;
  List<int> moveSteps;
  List<double> babySteps;
  List<int> extrudeSteps;
  double? lastPrintProgress;
  String? _lastPrintState;
  late List<MacroGroup> macroGroups;
  String? fcmIdentifier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is MachineSettings &&
          runtimeType == other.runtimeType &&
          temperaturePresets == other.temperaturePresets &&
          inverts == other.inverts &&
          speedXY == other.speedXY &&
          speedZ == other.speedZ &&
          extrudeFeedrate == other.extrudeFeedrate &&
          moveSteps == other.moveSteps &&
          babySteps == other.babySteps &&
          extrudeSteps == other.extrudeSteps &&
          lastPrintProgress == other.lastPrintProgress &&
          _lastPrintState == other._lastPrintState &&
          macroGroups == other.macroGroups &&
          fcmIdentifier == other.fcmIdentifier;

  @override
  int get hashCode =>
      super.hashCode ^
      temperaturePresets.hashCode ^
      inverts.hashCode ^
      speedXY.hashCode ^
      speedZ.hashCode ^
      extrudeFeedrate.hashCode ^
      moveSteps.hashCode ^
      babySteps.hashCode ^
      extrudeSteps.hashCode ^
      lastPrintProgress.hashCode ^
      _lastPrintState.hashCode ^
      macroGroups.hashCode ^
      fcmIdentifier.hashCode;

  @override
  String toString() {
    return 'Machine{temperaturePresets: $temperaturePresets, inverts: $inverts, speedXY: $speedXY, speedZ: $speedZ, extrudeFeedrate: $extrudeFeedrate, moveSteps: $moveSteps, babySteps: $babySteps, extrudeSteps: $extrudeSteps, lastPrintProgress: $lastPrintProgress, _lastPrintState: $_lastPrintState, macroGroups: $macroGroups, fcmIdentifier: $fcmIdentifier}';
  }
}
