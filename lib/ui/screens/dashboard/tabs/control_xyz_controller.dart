import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';

final controlXYZController =
    StateNotifierProvider.autoDispose<ControlXYZController, int>(
        (ref) {
          ref.keepAlive();
          return ControlXYZController(ref);
        });

class ControlXYZController extends StateNotifier<int> {
  ControlXYZController(this.ref) : super(0);

  Ref ref;

  onSelectedAxisStepSizeChanged(int index) {
    state = index;
  }

  onMoveBtn(PrinterAxis axis, [bool positive = true]) {
    MachineSettings machineSettings =
        ref.read(selectedMachineSettingsProvider).value!;
    var printerService = ref.read(printerServiceSelectedProvider);

    double step = machineSettings.moveSteps[state].toDouble();
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

  onHomeAxisBtn(Set<PrinterAxis> axis) {
    ref.read(printerServiceSelectedProvider).homePrintHead(axis);
  }

  onQuadGantry() {
    ref.read(printerServiceSelectedProvider).quadGantryLevel();
  }

  onBedMesh() {
    ref.read(printerServiceSelectedProvider).bedMeshLevel();
  }

  onMotorOff() {
    ref.read(printerServiceSelectedProvider).m84();
  }
}
