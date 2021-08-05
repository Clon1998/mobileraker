import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import 'package:mobileraker/app/AppSetup.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/dto/machine/WebcamSetting.dart';
import 'package:mobileraker/dto/server/Klipper.dart';
import 'package:mobileraker/service/KlippyService.dart';
import 'package:mobileraker/service/PrinterService.dart';
import 'package:mobileraker/service/SelectedMachineService.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';

class OverViewModel extends MultipleStreamViewModel {
  final _snackBarService = locator<SnackbarService>();
  final _navigationService = locator<NavigationService>();
  final _dialogService = locator<DialogService>();
  final _selectedMachineService = locator<SelectedMachineService>();
  GlobalKey<SliderMenuContainerState> menuContainerKey =
      GlobalKey<SliderMenuContainerState>();

  RefreshController refreshController =
      RefreshController(initialRefresh: false);
  PrinterSetting? _printerSetting;

  PrinterService? _printerService;
  KlippyService? _klippyService;

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey: StreamData<PrinterSetting?>(
            _selectedMachineService.selectedPrinter),
        if (_printerSetting?.printerService != null) ...{
          _PrinterStreamKey: StreamData<Printer>(_printerService!.printerStream)
        },

        if (_printerSetting?.klippyService != null) ...{
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream)
        }
        // _ServerStreamKey:
        // StreamData<KlipperInstance>(),
        // _PrinterStreamKey: StreamData<Printer>(),
      };

  bool get isPrinterSelected =>
      _selectedMachineService.selectedPrinter.hasValue;

  String get title =>
      '${_selectedMachineService.selectedPrinter.valueOrNull?.name ?? 'Printer'} - Dashboard';

  WebcamSetting? _camHack() {
    if (_printerSetting != null && _printerSetting!.cams.isNotEmpty) {
      return _printerSetting?.cams.first;
    }
    return null;
  }

  String? get webCamUrl {
    return _camHack()?.url;
  }

  double get webCamYSwap {
    var vertical = _camHack()?.flipVertical?? false;

    if (vertical)
      return pi;
    else
      return 0;
  }

  double get webCamXSwap {
    var horizontal = _camHack()?.flipVertical?? false;

    if (horizontal)
      return pi;
    else
      return 0;
  }

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get hasServer => dataReady(_ServerStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get hasPrinter => dataReady(_PrinterStreamKey);

  List<int> axisStepSize = [100, 25, 10, 1];

  int selectedAxisStepSizeIndex = 0;

  List<int> retractLengths = [1, 10, 25, 50];

  int selectedRetractLength = 0;

  List<double> babySteppingSizes = [0.01, 0.05, 0.1];

  int selectedBabySteppingSize = 0;

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case _SelectedPrinterStreamKey:
        PrinterSetting? nPrinterSetting = data;
        if (nPrinterSetting == _printerSetting) break;
        _printerSetting = nPrinterSetting;

        if (nPrinterSetting?.printerService != null) {
          _printerService = nPrinterSetting?.printerService;
        }

        if (nPrinterSetting?.klippyService != null) {
          _klippyService = nPrinterSetting?.klippyService;
        }
        notifySourceChanged(clearOldData: true);
        break;
      default:
        // Do nothing
        break;
    }
  }

  onRefresh() {
    var oldPrinter = _printerService?.printerStream.value;
    _printerService?.refreshPrinter();
    var subscription;
    subscription = _printerService?.printerStream.stream.listen((event) {
      if (event != oldPrinter) refreshController.refreshCompleted();
      subscription.cancel();
    });
  }

  onSelectedAxisStepSizeChanged(int index) {
    selectedAxisStepSizeIndex = index;
  }

  onSelectedBabySteppingSizeChanged(int index) {
    selectedBabySteppingSize = index;
  }

  onSelectedRetractChanged(int index) {
    selectedRetractLength = index;
  }

  onEmergencyPressed() {
    _klippyService?.emergencyStop();
  }

  onRestartMoonrakerPressed() {
    _klippyService?.restartMoonraker();
  }

  onRestartKlipperPressed() {
    _klippyService?.restartKlipper();
  }

  onRestartMCUPressed() {
    _klippyService?.restartMCUs();
  }

  onRestartHostPressed() {
    _klippyService?.rebootHost();
  }

  onPausePrintPressed() {
    _printerService?.pausePrint();
  }

  onCancelPrintPressed() {
    _printerService?.cancelPrint();
  }

  onResumePrintPressed() {
    _printerService?.resumePrint();
  }

  onMacroPressed(int macroIndex) {
    _printerService?.gCodeMacro(printer.gcodeMacros[macroIndex]);
  }

  editDialog([bool isHeatedBed = false]) {
    if (isHeatedBed) {
      _dialogService
          .showCustomDialog(
              variant: DialogType.editForm,
              title: "Edit Heated Bed Temperature",
              mainButtonTitle: "Confirm",
              secondaryButtonTitle: "Cancel",
              data: printer.heaterBed.target.round())
          .then((value) {
        if (value != null && value.confirmed && value.data != null) {
          num v = value.data;
          _printerService?.setTemperature('heater_bed', v.toInt());
        }
      });
    } else {
      _dialogService
          .showCustomDialog(
              variant: DialogType.editForm,
              title: "Edit Extruder Temperature",
              mainButtonTitle: "Confirm",
              secondaryButtonTitle: "Cancel",
              data: printer.extruder.target.round())
          .then((value) {
        if (value != null && value.confirmed && value.data != null) {
          num v = value.data;
          _printerService?.setTemperature('extruder', v.toInt());
        }
      });
    }
  }

  onMoveBtn(PrinterAxis axis, [bool positive = true]) {
    double step = axisStepSize[selectedAxisStepSizeIndex].toDouble();
    double dirStep = (positive) ? step : -1 * step;
    switch (axis) {
      case PrinterAxis.X:
        _printerService?.movePrintHead(x: dirStep);
        break;
      case PrinterAxis.Y:
        _printerService?.movePrintHead(y: dirStep);
        break;
      case PrinterAxis.Z:
        _printerService?.movePrintHead(z: dirStep);
        break;
    }
  }

  onBabyStepping([bool positive = true]) {
    double step = babySteppingSizes[selectedBabySteppingSize].toDouble();
    double dirStep = (positive) ? step : -1 * step;
    int? m = (printer.toolhead.homedAxes
            .containsAll({PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z}))
        ? 1
        : null;
    _printerService?.setGcodeOffset(z: dirStep, move: m);
  }

  onHomeAxisBtn(Set<PrinterAxis> axis) {
    _printerService?.homePrintHead(axis);
  }

  onPartFanSlider(double value) {
    _printerService?.partCoolingFan(value);
  }

  onRetractBtn() {
    var double = (retractLengths[selectedRetractLength] * -1).toDouble();
    _printerService?.moveExtruder(double);
  }

  onDeRetractBtn() {
    var double = (retractLengths[selectedRetractLength]).toDouble();
    _printerService?.moveExtruder(double);
  }

  onQuadGantry() {
    _printerService?.quadGantryLevel();
  }

  onBedMesh() {
    _printerService?.bedMeshLevel();
  }

  navigateToSettings() {
    //Navigate to other View:::
    _navigationService.navigateTo(Routes.settingView);
  }

  showNotImplementedToast() {
    _snackBarService.showSnackbar(message: "WIP!... Not implemented yet.");
  }

  fffff() {
    // _navigationService.navigateTo(Routes.testView);
    // print("asdasd");
  }
}
