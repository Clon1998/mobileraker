import 'dart:math';

import 'package:flip_card/flip_card.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/domain/temperature_preset.dart';
import 'package:mobileraker/domain/webcam_setting.dart';
import 'package:mobileraker/dto/files/gcode_file.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/machine/toolhead.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/enums/dialog_type.dart';
import 'package:mobileraker/service/file_service.dart';
import 'package:mobileraker/service/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/dialog/editForm/num_edit_form_view.dart';
import 'package:mobileraker/ui/views/setting/setting_viewmodel.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';

class GeneralTabViewModel extends MultipleStreamViewModel {
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();
  final _navigationService = locator<NavigationService>();
  final _settingService = locator<SettingService>();

  PrinterSetting? _printerSetting;
  int _printerSettingHash = -1;

  PrinterService? get _printerService => _printerSetting?.printerService;

  KlippyService? get _klippyService => _printerSetting?.klippyService;

  FileService? get _fileService => _printerSetting?.fileService;

  GlobalKey<FlipCardState> tmpCardKey = GlobalKey<FlipCardState>();

  int selectedIndexAxisStepSizeIndex = 0;

  int selectedIndexBabySteppingSize = 0;

  GCodeFile? currentFile;

  WebcamSetting? selectedCam;


  ScrollController _tempsScrollController = new ScrollController(
    keepScrollOffset: true,
  );
  ScrollController get tempsScrollController => _tempsScrollController;

  ScrollController _presetsScrollController = new ScrollController(
    keepScrollOffset: true,
  );
  ScrollController get presetsScrollController => _presetsScrollController;

  int get tempsSteps => 2+printer.temperatureSensors.length;

  int get presetSteps => 1 + temperaturePresets.length;

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<PrinterSetting?>(_machineService.selectedMachine),
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
        if (nPrinterSetting == _printerSetting &&
            nPrinterSetting.hashCode == _printerSettingHash) break;
        _printerSetting = nPrinterSetting;
        _printerSettingHash = nPrinterSetting.hashCode;
        List<WebcamSetting>? tmpCams = _printerSetting?.cams;
        if (tmpCams?.isNotEmpty ?? false)
          selectedCam = tmpCams!.first;
        else
          selectedCam = null;
        notifySourceChanged(clearOldData: true);
        break;

      case _PrinterStreamKey:
        Printer nPrinter = data;

        String filename = nPrinter.print.filename;
        if (filename.isNotEmpty && currentFile?.pathForPrint != filename)
          _fileService!
              .getGCodeMetadata(filename)
              .then((value) => currentFile = value);

        break;
      default:
        // Do nothing
        break;
    }
  }

  bool get canUsePrinter => server.klippyState == KlipperState.ready && server.klippyConnected;

  bool get isMachineAvailable => dataReady(_SelectedPrinterStreamKey);

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get isServerAvailable => dataReady(_ServerStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get isPrinterAvailable => dataReady(_PrinterStreamKey);

  String get status {
    if (server.klippyState == KlipperState.ready) {
      return printer.print.stateName;
    } else
      return server.klippyStateMessage ??
          'Klipper: ${toName(server.klippyState)}';
  }

  List<int> get axisStepSize {
    return _printerSetting?.moveSteps.toList() ?? const [100, 25, 10, 1];
  }

  List<double> get babySteppingSizes {
    return _printerSetting?.babySteps.toList() ?? const [0.005, 0.01, 0.05, 0.1];
  }

  List<TemperaturePreset> get temperaturePresets {
    return _printerSetting?.temperaturePresets.toList() ?? List.empty();
  }

  List<WebcamSetting> get webcams {
    if (_printerSetting != null && _printerSetting!.cams.isNotEmpty) {
      return _printerSetting!.cams;
    }
    return List.empty();
  }

  bool get webCamAvailable => webcams.isNotEmpty && selectedCam != null;

  String get webCamUrl {
    return selectedCam!.url;
  }

  double get yTransformation {
    var vertical = selectedCam?.flipVertical ?? false;

    if (vertical)
      return pi;
    else
      return 0;
  }

  double get xTransformation {
    var horizontal = selectedCam?.flipVertical ?? false;

    if (horizontal)
      return pi;
    else
      return 0;
  }

  Matrix4 get transformMatrix => Matrix4.identity()
    ..rotateX(xTransformation)
    ..rotateY(yTransformation);

  setTemperaturePreset(int extruderTemp, int bedTemp) {
    _printerService?.setTemperature('extruder', extruderTemp);
    _printerService?.setTemperature('heater_bed', bedTemp);
    flipTemperatureCard();
  }

  editDialog([bool isHeatedBed = false]) {
    if (isHeatedBed) {
      _dialogService
          .showCustomDialog(
              variant: DialogType.numEditForm,
              title: "Edit Heated Bed Temperature",
              mainButtonTitle: "Confirm",
              secondaryButtonTitle: "Cancel",
              data: NumEditFormDialogViewArguments(
                  current: printer.heaterBed.target.round(),
                  min: 0,
                  max: printer.configFile.configHeaterBed?.maxTemp.toInt() ??
                      150))
          .then((value) {
        if (value != null && value.confirmed && value.data != null) {
          num v = value.data;
          _printerService?.setTemperature('heater_bed', v.toInt());
        }
      });
    } else {
      _dialogService
          .showCustomDialog(
              variant: DialogType.numEditForm,
              title: "Edit Extruder Temperature",
              mainButtonTitle: "Confirm",
              secondaryButtonTitle: "Cancel",
              data: NumEditFormDialogViewArguments(
                  current: printer.extruder.target.round(),
                  min: 0,
                  max: printer.configFile.primaryExtruder?.maxTemp.toInt() ??
                      500))
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
        if (_printerSetting!.inverts[0]) dirStep *= -1;
        _printerService?.movePrintHead(
            x: dirStep, feedRate: _printerSetting!.speedXY.toDouble());
        break;
      case PrinterAxis.Y:
        if (_printerSetting!.inverts[1]) dirStep *= -1;
        _printerService?.movePrintHead(
            y: dirStep, feedRate: _printerSetting!.speedXY.toDouble());
        break;
      case PrinterAxis.Z:
        if (_printerSetting!.inverts[2]) dirStep *= -1;
        _printerService?.movePrintHead(
            z: dirStep, feedRate: _printerSetting!.speedZ.toDouble());
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

  flipTemperatureCard() {
    tmpCardKey.currentState?.toggleCard();
  }

  onFullScreenTap() {
    _navigationService.navigateTo(Routes.fullCamView,
        arguments: FullCamViewArguments(webcamSetting: selectedCam!));
  }

  onResetPrintTap() {
    _printerService?.resetPrintStat();
  }

  onWebcamSettingSelected(WebcamSetting? webcamSetting) {
    selectedCam = webcamSetting;
  }

  bool get isPrinting => printer.print.state == PrintState.printing;

  bool get showBabyStepping =>
      isPrinting || _settingService.readBool(showBabyAlwaysKey);

  bool get isNotPrinting => !isPrinting;

  int get maxLayers {
    if (!_canCalcMaxLayer) return 0;
    GCodeFile crntFile = currentFile!;
    int max = ((crntFile.objectHeight! - crntFile.firstLayerHeight!) /
                crntFile.layerHeight! +
            1)
        .ceil();
    return max > 0 ? max : 0;
  }

  bool get _canCalcMaxLayer =>
      isPrinterAvailable &&
      currentFile != null &&
      currentFile!.firstLayerHeight != null &&
      currentFile!.layerHeight != null &&
      currentFile!.objectHeight != null;

  int get layer {
    if (!_canCalcLayer) return 0;
    GCodeFile crntFile = currentFile!;
    int currentLayer =
        ((printer.toolhead.position[2] - crntFile.firstLayerHeight!) /
                    crntFile.layerHeight! +
                1)
            .ceil();
    currentLayer = (currentLayer <= maxLayers) ? currentLayer : maxLayers;
    return currentLayer > 0 ? currentLayer : 0;
  }

  bool get _canCalcLayer =>
      isPrinterAvailable &&
      currentFile != null &&
      currentFile!.firstLayerHeight != null &&
      currentFile!.layerHeight != null;

  onRestartKlipperPressed() {
    _klippyService?.restartKlipper();
  }

  onRestartMCUPressed() {
    _klippyService?.restartMCUs();
  }
}
