import 'package:flip_card/flip_card.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/machine/temperature_sensor.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/model/hive/machine.dart';
import 'package:mobileraker/model/hive/webcam_setting.dart';
import 'package:mobileraker/model/moonraker/machine_settings.dart';
import 'package:mobileraker/model/moonraker/temperature_preset.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/components/dialog/editForm/range_edit_form_view.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';
const String _MachineSettingsStreamKey = 'machineSettings';

class GeneralTabViewModel extends MultipleStreamViewModel {
  final _dialogService = locator<DialogService>();
  final _selectedMachineService = locator<SelectedMachineService>();
  final _machineService = locator<MachineService>();
  final _navigationService = locator<NavigationService>();
  final _settingService = locator<SettingService>();

  Machine? _machine;
  int _machineHash = -1;

  GlobalKey<FlipCardState> tmpCardKey = GlobalKey<FlipCardState>();

  int selectedIndexAxisStepSizeIndex = 0;

  int selectedIndexBabySteppingSize = 0;

  GCodeFile? currentFile;

  WebcamSetting? selectedCam;

  ScrollController _tempsScrollController = new ScrollController();

  ScrollController get tempsScrollController => _tempsScrollController;

  ScrollController _presetsScrollController = new ScrollController();

  ScrollController get presetsScrollController => _presetsScrollController;

  PrinterService? get _printerService => _machine?.printerService;

  KlippyService? get _klippyService => _machine?.klippyService;

  FileService? get _fileService => _machine?.fileService;

  bool get isDataReady =>
      isPrinterAvailable &&
      isServerAvailable &&
      isMachineAvailable &&
      isMachineSettingsAvailable;

  int get tempsSteps => 2 + printer.temperatureSensors.length;

  int get presetSteps => 1 + temperaturePresets.length;

  Set<TemperatureSensor> get filteredSensors => printer.temperatureSensors
      .where((TemperatureSensor element) => !element.name.startsWith("_"))
      .toSet();

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<Machine?>(_selectedMachineService.selectedMachine),
        if (_machine != null)
          _MachineSettingsStreamKey: StreamData<MachineSettings>(
              _machineService.fetchSettings(_machine!).asStream()),
        if (_machine?.printerService != null)
          _PrinterStreamKey:
              StreamData<Printer>(_printerService!.printerStream),
        if (_machine?.klippyService != null)
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream),
      };

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case _SelectedPrinterStreamKey:
        Machine? nmachine = data;
        if (nmachine == _machine && nmachine.hashCode == _machineHash) break;
        _machine = nmachine;
        _machineHash = nmachine.hashCode;
        List<WebcamSetting>? tmpCams = _machine?.cams;
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

  bool get canUsePrinter =>
      server.klippyState == KlipperState.ready && server.klippyConnected;

  bool get isMachineAvailable => dataReady(_SelectedPrinterStreamKey);

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get isServerAvailable => dataReady(_ServerStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get isPrinterAvailable => dataReady(_PrinterStreamKey);

  MachineSettings get machineSettings => dataMap![_MachineSettingsStreamKey];

  bool get isMachineSettingsAvailable => dataReady(_MachineSettingsStreamKey);

  String get status {
    if (server.klippyState == KlipperState.ready) {
      return printer.print.stateName;
    } else
      return server.klippyStateMessage ??
          'Klipper: ${toName(server.klippyState)}';
  }

  List<int> get axisStepSize => machineSettings.moveSteps;

  List<double> get babySteppingSizes => machineSettings.babySteps;

  List<TemperaturePreset> get temperaturePresets =>
      machineSettings.temperaturePresets;

  List<WebcamSetting> get webcams {
    if (_machine != null && _machine!.cams.isNotEmpty) {
      return _machine!.cams;
    }
    return List.empty();
  }

  bool get webCamAvailable => webcams.isNotEmpty && selectedCam != null;

  adjustNozzleAndBed(int extruderTemp, int bedTemp) {
    _printerService?.setTemperature('extruder', extruderTemp);
    _printerService?.setTemperature('heater_bed', bedTemp);
    flipTemperatureCard();
  }

  editDialog([bool isHeatedBed = false]) {
    if (isHeatedBed) {
      numberOrRangeDialog(
              dialogService: _dialogService,
              settingService: _settingService,
              title: "Edit Heated Bed Temperature",
              mainButtonTitle: "Confirm",
              secondaryButtonTitle: "Cancel",
              data: NumberEditDialogArguments(
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
      numberOrRangeDialog(
              dialogService: _dialogService,
              settingService: _settingService,
              title: "Edit Extruder Temperature",
              mainButtonTitle: "Confirm",
              secondaryButtonTitle: "Cancel",
              data: NumberEditDialogArguments(
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
        if (machineSettings.inverts[0]) dirStep *= -1;
        _printerService?.movePrintHead(
            x: dirStep, feedRate: machineSettings.speedXY.toDouble());
        break;
      case PrinterAxis.Y:
        if (machineSettings.inverts[1]) dirStep *= -1;
        _printerService?.movePrintHead(
            y: dirStep, feedRate: machineSettings.speedXY.toDouble());
        break;
      case PrinterAxis.Z:
        if (machineSettings.inverts[2]) dirStep *= -1;
        _printerService?.movePrintHead(
            z: dirStep, feedRate: machineSettings.speedZ.toDouble());
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

  onMotorOff() {
    _printerService?.m84();
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
        arguments: FullCamViewArguments(
            webcamSetting: selectedCam!, owner: _machine!));
  }

  onResetPrintTap() {
    _printerService?.resetPrintStat();
  }

  onWebcamSettingSelected(WebcamSetting? webcamSetting) {
    selectedCam = webcamSetting;
  }

  bool get isPrinting => printer.print.state == PrintState.printing;

  bool get isPaused => printer.print.state == PrintState.paused;

  bool get showBabyStepping =>
      isPrinting || isPaused || _settingService.readBool(showBabyAlwaysKey);

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
    if (!isPrinterAvailable ||
        currentFile?.firstLayerHeight == null ||
        currentFile?.layerHeight == null) return 0;
    GCodeFile crntFile = currentFile!;
    int currentLayer =
        ((printer.toolhead.position[2] - crntFile.firstLayerHeight!) /
                    crntFile.layerHeight! +
                1)
            .ceil();
    currentLayer = (currentLayer <= maxLayers) ? currentLayer : maxLayers;
    return currentLayer > 0 ? currentLayer : 0;
  }

  onRestartKlipperPressed() {
    _klippyService?.restartKlipper();
  }

  onRestartMCUPressed() {
    _klippyService?.restartMCUs();
  }
}
