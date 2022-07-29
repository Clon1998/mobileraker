import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/extruder.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/machine/temperature_sensor.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';
import 'package:mobileraker/data/model/moonraker_db/temperature_preset.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/common/mixins/klippy_mixin.dart';
import 'package:mobileraker/ui/common/mixins/machine_settings_mixin.dart';
import 'package:mobileraker/ui/common/mixins/printer_mixin.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_viewmodel.dart';
import 'package:mobileraker/ui/components/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/util/extensions/list_extension.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:stringr/stringr.dart';

class GeneralTabViewModel extends MultipleStreamViewModel
    with SelectedMachineMixin, PrinterMixin, KlippyMixin, MachineSettingsMixin {
  final _logger = getLogger('GeneralTabViewModel');

  final _dialogService = locator<DialogService>();
  final _navigationService = locator<NavigationService>();
  final _settingService = locator<SettingService>();

  GlobalKey<FlipCardState> tmpCardKey = GlobalKey<FlipCardState>();

  int selectedIndexAxisStepSizeIndex = 0;

  int selectedIndexBabySteppingSize = 0;

  GCodeFile? currentFile;

  WebcamSetting? selectedCam;

  List<WebcamSetting> get webcams {
    if (isSelectedMachineReady && selectedMachine!.cams.isNotEmpty) {
      return selectedMachine!.cams;
    }
    return [];
  }

  bool get webCamAvailable => webcams.isNotEmpty && selectedCam != null;

  bool get isDataReady =>
      isSelectedMachineReady &&
      isPrinterDataReady &&
      isKlippyInstanceReady &&
      isMachineSettingsReady;

  int get tempsSteps => 2 + printerData.temperatureSensors.length;

  int get presetSteps => 1 + temperaturePresets.length;

  String get status {
    if (klippyInstance.klippyState == KlipperState.ready) {
      return printerData.print.stateName;
    } else
      return klippyInstance.klippyStateMessage ??
          'Klipper: ${toName(klippyInstance.klippyState)}';
  }

  List<int> get axisStepSize => machineSettings.moveSteps;

  List<double> get babySteppingSizes => machineSettings.babySteps;

  List<TemperaturePreset> get temperaturePresets =>
      machineSettings.temperaturePresets;

  bool get showBabyStepping =>
      isPrintingOrPaused || _settingService.readBool(showBabyAlwaysKey);

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
      isPrinterDataReady &&
      currentFile != null &&
      currentFile!.firstLayerHeight != null &&
      currentFile!.layerHeight != null &&
      currentFile!.objectHeight != null;

  int get layer {
    if (!isPrinterDataReady ||
        currentFile?.firstLayerHeight == null ||
        currentFile?.layerHeight == null) return 0;
    GCodeFile crntFile = currentFile!;
    int currentLayer =
        ((printerData.toolhead.position[2] - crntFile.firstLayerHeight!) /
                    crntFile.layerHeight! +
                1)
            .ceil();
    currentLayer = (currentLayer <= maxLayers) ? currentLayer : maxLayers;
    return currentLayer > 0 ? currentLayer : 0;
  }

  Set<TemperatureSensor> get filteredSensors => printerData.temperatureSensors
      .where((TemperatureSensor element) => !element.name.startsWith("_"))
      .toSet();

  @override
  Map<String, StreamData> get streamsMap => super.streamsMap;

  FlSpotKeeper heatedBedKeeper = FlSpotKeeper();
  Map<int, FlSpotKeeper> extrudersKeepers = {};
  Map<String, FlSpotKeeper> sensorsKeepers = {};

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case SelectedMachineMixin.StreamKey:
        selectedCam = selectedMachine?.cams.firstOrNull;
        break;
      case PrinterMixin.StreamKey:
        Printer nPrinter = data;
        String filename = nPrinter.print.filename;
        if (filename.isNotEmpty && currentFile?.pathForPrint != filename)
          fileService
              .getGCodeMetadata(filename)
              .then((value) => currentFile = value);

        updatePlotsIfNewAvailable(nPrinter);

        break;
      default:
        // Do nothing
        break;
    }
  }

  void updatePlotsIfNewAvailable(Printer nPrinter) {
    nPrinter.extruders.forEach((ext) {
      if (ext == null) return;
      extrudersKeepers.putIfAbsent(ext.num, () => FlSpotKeeper());

      final FlSpotKeeper spotKeeper = extrudersKeepers[ext.num]!;
      _convertToPlotSpots(spotKeeper, ext.temperatureHistory);
    });
    nPrinter.temperatureSensors.forEach((sensor) {
      sensorsKeepers.putIfAbsent(sensor.name, () => FlSpotKeeper());
      final FlSpotKeeper spotKeeper = sensorsKeepers[sensor.name]!;
      _convertToPlotSpots(spotKeeper, sensor.temperatureHistory);
    });

    _convertToPlotSpots(
        heatedBedKeeper, nPrinter.heaterBed.temperatureHistory);
  }

  adjustNozzleAndBed(int extruderTemp, int bedTemp) {
    printerService.setTemperature('extruder', extruderTemp);
    printerService.setTemperature('heater_bed', bedTemp);
    flipTemperatureCard();
  }

  editExtruderHeater([int extruderIndex = 0]) {
    Extruder extruder = printerData.extruderFromIndex(extruderIndex);
    numberOrRangeDialog(
            dialogService: _dialogService,
            settingService: _settingService,
            title:
                'Edit Extruder ${extruderIndex > 0 ? '$extruderIndex' : ''} Temperature',
            mainButtonTitle: "Confirm",
            secondaryButtonTitle: "Cancel",
            data: NumberEditDialogArguments(
                current: extruder.target.round(),
                min: 0,
                max: printerData.configFile
                        .extruderForIndex(extruderIndex)
                        ?.maxTemp
                        .toInt() ??
                    300))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        printerService.setTemperature(
            'extruder${extruderIndex > 0 ? extruderIndex : ''}', v.toInt());
      }
    });
  }

  editHeatedBed() {
    numberOrRangeDialog(
            dialogService: _dialogService,
            settingService: _settingService,
            title: "Edit Heated Bed Temperature",
            mainButtonTitle: "Confirm",
            secondaryButtonTitle: "Cancel",
            data: NumberEditDialogArguments(
                current: printerData.heaterBed.target.round(),
                min: 0,
                max: printerData.configFile.configHeaterBed?.maxTemp.toInt() ??
                    150))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        printerService.setTemperature('heater_bed', v.toInt());
      }
    });
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
      case PrinterAxis.E:
      // Do nothing! Since no invocation with E will be done!
    }
  }

  onHomeAxisBtn(Set<PrinterAxis> axis) {
    printerService.homePrintHead(axis);
  }

  onQuadGantry() {
    printerService.quadGantryLevel();
  }

  onBedMesh() {
    printerService.bedMeshLevel();
  }

  onMotorOff() {
    printerService.m84();
  }

  onSelectedBabySteppingSizeChanged(int index) {
    selectedIndexBabySteppingSize = index;
  }

  onBabyStepping([bool positive = true]) {
    double step = babySteppingSizes[selectedIndexBabySteppingSize].toDouble();
    double dirStep = (positive) ? step : -1 * step;
    int? m = (printerData.toolhead.homedAxes
            .containsAll({PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z}))
        ? 1
        : null;
    printerService.setGcodeOffset(z: dirStep, move: m);
  }

  flipTemperatureCard() {
    tmpCardKey.currentState?.toggleCard();
  }

  onFullScreenTap() {
    _navigationService.navigateTo(Routes.fullCamView,
        arguments: FullCamViewArguments(
            webcamSetting: selectedCam!, owner: selectedMachine!));
  }

  onResetPrintTap() {
    printerService.resetPrintStat();
  }

  onWebcamSettingSelected(WebcamSetting? webcamSetting) {
    selectedCam = webcamSetting;
  }

  onRestartKlipperPressed() {
    klippyService.restartKlipper();
  }

  onRestartMCUPressed() {
    klippyService.restartMCUs();
  }

  onExcludeObjectPressed() {
    _dialogService.showCustomDialog(variant: DialogType.excludeObject);
  }

  _convertToPlotSpots(FlSpotKeeper keeper, List<double>? doubles) {
    if (doubles == null) return;
    final nHash = hashAllNullable(doubles);
    if (nHash == keeper.lastHash) return;

    heatedBedKeeper.lastHash = nHash;
    List<double> sublist = doubles.sublist(max(0, doubles.length - 300));
    keeper.spots.clear();
    keeper.spots.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
  }
}

class FlSpotKeeper {
  final List<FlSpot> spots = [];
  int lastHash = -1;
}
