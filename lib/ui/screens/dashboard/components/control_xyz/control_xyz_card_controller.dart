import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'control_xyz_card_controller.freezed.dart';

part 'control_xyz_card_controller.g.dart';

@freezed
class ControlXYZState with _$ControlXYZState {
  const factory ControlXYZState(
      {@Default(0) int index,
      @Default(false) bool homing,
      @Default(false) bool qgl,
      @Default(false) bool mesh,
      @Default(false) bool motorsOff,
      @Default(false) bool zTilt,
      @Default(false) bool screwTilt}) = _ControlXYZState;
}

@riverpod
class ControlXYZCardController extends _$ControlXYZCardController {
  @override
  ControlXYZState build() {
    return const ControlXYZState();
  }

  onSelectedAxisStepSizeChanged(int index) {
    state = state.copyWith(index: index);
  }

  onMoveBtn(PrinterAxis axis, [bool positive = true]) {
    MachineSettings machineSettings =
        ref.read(selectedMachineSettingsProvider).value!;
    var printerService = ref.read(printerServiceSelectedProvider);

    double step = machineSettings.moveSteps[state.index].toDouble();
    double dirStep = (positive) ? step : -1 * step;

    switch (axis) {
      case PrinterAxis.X:
        if (machineSettings.inverts[0]) dirStep *= -1;
        printerService.movePrintHead(
            x: dirStep, feedRate: machineSettings.speedXY.toDouble());
        break;
      case PrinterAxis.Y:
        if (machineSettings.inverts[1]) dirStep *= -1;
        printerService.movePrintHead(
            y: dirStep, feedRate: machineSettings.speedXY.toDouble());
        break;
      case PrinterAxis.Z:
        if (machineSettings.inverts[2]) dirStep *= -1;
        printerService.movePrintHead(
            z: dirStep, feedRate: machineSettings.speedZ.toDouble());
        break;
      default:
        throw const MobilerakerException('Unreachable');
    }
  }

  onHomeAxisBtn(Set<PrinterAxis> axis) async {
    state = state.copyWith(homing: true);
    await ref.read(printerServiceSelectedProvider).homePrintHead(axis);
    state = state.copyWith(homing: false);
  }

  onQuadGantry() async {
    state = state.copyWith(qgl: true);
    await ref.read(printerServiceSelectedProvider).quadGantryLevel();
    state = state.copyWith(qgl: false);
  }

  onBedMesh() async {
    state = state.copyWith(mesh: true);
    await ref.read(printerServiceSelectedProvider).bedMeshLevel();
    state = state.copyWith(mesh: false);
  }

  onMotorOff() async {
    state = state.copyWith(motorsOff: true);
    await ref.read(printerServiceSelectedProvider).m84();
    state = state.copyWith(motorsOff: false);
  }

  onZTiltAdjust() async {
    state = state.copyWith(zTilt: true);
    await ref.read(printerServiceSelectedProvider).zTiltAdjust();
    state = state.copyWith(zTilt: false);
  }

  onScrewTiltCalc() async {
    state = state.copyWith(screwTilt: true);
    await ref.read(printerServiceSelectedProvider).screwsTiltCalculate();
    state = state.copyWith(screwTilt: false);
  }

  reset() {
    state = state.copyWith(
        screwTilt: false,
        zTilt: false,
        motorsOff: false,
        mesh: false,
        qgl: false,
        homing: false);
  }
}
