import 'dart:math';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:mobileraker/app/AppSetup.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/dto/server/Klipper.dart';
import 'package:mobileraker/service/KlippyService.dart';
import 'package:mobileraker/service/PrinterService.dart';
import 'package:simple_logger/simple_logger.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _PrinterStreamKey = 'printer';

class OverViewModel extends MultipleStreamViewModel {
  final _navigationService = locator<NavigationService>();
  final _dialogService = locator<DialogService>();
  final _printerService = locator<PrinterService>();
  final _klippyService = locator<KlippyService>();
  final _snackBarService = locator<SnackbarService>();
  final logger = locator<SimpleLogger>();

  String get title =>
      '${Settings.getValue('klipper.name', 'Printer')} - Dashboard';

  KlipperInstance get server => dataMap[_ServerStreamKey];

  bool get hasServer => dataReady(_ServerStreamKey);

  Printer get printer => dataMap[_PrinterStreamKey];

  bool get hasPrinter => dataReady(_PrinterStreamKey);

  List<int> axisStepSize = [100, 25, 10, 1];

  int selectedAxisStepSizeIndex = 0;

  List<int> retractLengths = [1, 10, 25, 50];

  int selectedRetractLength = 0;

  List<double> babySteppingSizes = [0.01, 0.05, 0.1];

  int selectedBabySteppingSize = 0;

  @override
  Map<String, StreamData> get streamsMap => {
        _ServerStreamKey:
            StreamData<KlipperInstance>(_klippyService.fetchKlippy()),
        _PrinterStreamKey: StreamData<Printer>(_printerService.fetchPrinter()),
      };

  onSelectedAxisStepSizeChanged(int index) {
    selectedAxisStepSizeIndex = index;
  }

  onSelectedBabySteppingSizeChanged(int index) {
    selectedBabySteppingSize = index;
  }

  onSelectedRetractChanged(int index) {
    selectedRetractLength = index;
  }

  void onEmergencyPressed() {
    _klippyService.emergencyStop();
  }

  void onRestartMoonrakerPressed() {
    _klippyService.restartMoonraker();
  }

  void onRestartKlipperPressed() {
    _klippyService.restartKlipper();
  }

  void onRestartMCUPressed() {
    _klippyService.restartMCUs();
  }

  void onRestartHostPressed() {
    _klippyService.rebootHost();
  }

  void onPausePrintPressed() {
    _printerService.pausePrint();
  }

  void onCancelPrintPressed() {
    _printerService.cancelPrint();
  }

  void onResumePrintPressed() {
    _printerService.resumePrint();
  }

  void onMacroPressed(int macroIndex) {
    _printerService.gCodeMacro(printer.gcodeMacros[macroIndex]);
  }

  void editDialog([bool isHeatedBed = false]) {
    if (isHeatedBed) {
      _dialogService
          .showCustomDialog(
              variant: DialogType.editForm,
              title: "Edit Heated Bed Temperature",
              mainButtonTitle: "Confirm",
              secondaryButtonTitle: "Cancel",
              customData: printer.heaterBed.target.round())
          .then((value) {
        if (value != null && value.confirmed && value.responseData != null) {
          num v = value.responseData;
          _printerService.setTemperature('heater_bed', v);
        }
      });
    } else {
      _dialogService
          .showCustomDialog(
              variant: DialogType.editForm,
              title: "Edit Extruder Temperature",
              mainButtonTitle: "Confirm",
              secondaryButtonTitle: "Cancel",
              customData: printer.extruder.target.round())
          .then((value) {
        if (value != null && value.confirmed && value.responseData != null) {
          num v = value.responseData;
          _printerService.setTemperature('extruder', v);
        }
      });
    }
  }

  void onMoveBtn(PrinterAxis axis, [bool positive = true]) {
    double step = axisStepSize[selectedAxisStepSizeIndex].toDouble();
    double dirStep = (positive) ? step : -1 * step;
    switch (axis) {
      case PrinterAxis.X:
        _printerService.movePrintHead(x: dirStep);
        break;
      case PrinterAxis.Y:
        _printerService.movePrintHead(y: dirStep);
        break;
      case PrinterAxis.Z:
        _printerService.movePrintHead(z: dirStep);
        break;
    }
  }

  void onBabyStepping([bool positive = true]) {
    double step = babySteppingSizes[selectedBabySteppingSize].toDouble();
    double dirStep = (positive) ? step : -1 * step;
    int m = (printer.toolhead.homedAxes
            .containsAll({PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z}))
        ? 1
        : null;
    _printerService.setGcodeOffset(z: dirStep, move: m);
  }

  void onHomeAxisBtn(Set<PrinterAxis> axis) {
    _printerService.homePrintHead(axis);
  }

  void onRetractBtn() {
    var double = (retractLengths[selectedRetractLength] * -1).toDouble();
    _printerService.moveExtruder(double);
  }

  void onDeRetractBtn() {
    var double = (retractLengths[selectedRetractLength]).toDouble();
    _printerService.moveExtruder(double);
  }

  void onQuadGantry() {
    _printerService.quadGantryLevel();
  }

  void onBedMesh() {
    _printerService.bedMeshLevel();
  }

  void navigateToSettings() {
    //Navigate to other View:::
    _navigationService.navigateTo(Routes.settingView);
  }

  void showNotImplementedToast() {
    _snackBarService.showSnackbar(message: "WIP!... Not implemented yet.");
  }

  void fffff() {
    _navigationService.navigateTo(Routes.testView);
    // print("asdasd");
  }
}
