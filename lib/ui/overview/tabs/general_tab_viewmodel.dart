import 'dart:math';

import 'package:mobileraker/app/AppSetup.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/dto/machine/WebcamSetting.dart';
import 'package:mobileraker/dto/server/Klipper.dart';
import 'package:mobileraker/service/KlippyService.dart';
import 'package:mobileraker/service/PrinterService.dart';
import 'package:mobileraker/service/MachineService.dart';
import 'package:mobileraker/ui/dialog/editForm/editForm_view.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';

class GeneralTabViewModel extends MultipleStreamViewModel {
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();

  PrinterSetting? _printerSetting;
  PrinterService? _printerService;
  KlippyService? _klippyService;

  List<int> axisStepSize = [100, 25, 10, 1];
  int selectedIndexAxisStepSizeIndex = 0;

  List<double> babySteppingSizes = [0.005, 0.01, 0.05, 0.1];
  int selectedIndexBabySteppingSize = 0;

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey: StreamData<PrinterSetting?>(
            _machineService.selectedPrinter),
        if (_printerSetting?.printerService != null) ...{
          _PrinterStreamKey: StreamData<Printer>(_printerService!.printerStream)
        },
        if (_printerSetting?.klippyService != null) ...{
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream)
        }
      };

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

  bool get isPrinterSelected => dataReady(_SelectedPrinterStreamKey);

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get hasServer => dataReady(_ServerStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get hasPrinter => dataReady(_PrinterStreamKey);

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
    var vertical = _camHack()?.flipVertical ?? false;

    if (vertical)
      return pi;
    else
      return 0;
  }

  double get webCamXSwap {
    var horizontal = _camHack()?.flipVertical ?? false;

    if (horizontal)
      return pi;
    else
      return 0;
  }

  editDialog([bool isHeatedBed = false]) {
    if (isHeatedBed) {
      _dialogService
          .showCustomDialog(
              variant: DialogType.editForm,
              title: "Edit Heated Bed Temperature",
              mainButtonTitle: "Confirm",
              secondaryButtonTitle: "Cancel",
              data: EditFormDialogViewArguments(
                  current: printer.heaterBed.target.round(),
                  max: 150)) //ToDo: read from config file
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
              data: EditFormDialogViewArguments(
                  current: printer.extruder.target.round(),
                  max: 500)) //ToDo: read from config file
          .then((value) {
        if (value != null && value.confirmed && value.data != null) {
          num v = value.data;
          _printerService?.setTemperature('extruder', v.toInt());
        }
      });
    }
  }

  onSelectedAxisStepSizeChanged(int index) {
    selectedIndexAxisStepSizeIndex = index;
  }

  onMoveBtn(PrinterAxis axis, [bool positive = true]) {
    double step = axisStepSize[selectedIndexAxisStepSizeIndex].toDouble();
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

  onHomeAxisBtn(Set<PrinterAxis> axis) {
    _printerService?.homePrintHead(axis);
  }

  onQuadGantry() {
    _printerService?.quadGantryLevel();
  }

  onBedMesh() {
    _printerService?.bedMeshLevel();
  }

  onSelectedBabySteppingSizeChanged(int index) {
    selectedIndexBabySteppingSize = index;
  }

  onBabyStepping([bool positive = true]) {
    double step = babySteppingSizes[selectedIndexBabySteppingSize].toDouble();
    double dirStep = (positive) ? step : -1 * step;
    int? m = (printer.toolhead.homedAxes
            .containsAll({PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z}))
        ? 1
        : null;
    _printerService?.setGcodeOffset(z: dirStep, move: m);
  }
}
