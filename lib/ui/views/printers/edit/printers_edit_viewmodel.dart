import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/domain/temperature_preset.dart';
import 'package:mobileraker/domain/webcam_setting.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class PrintersEditViewModel extends BaseViewModel {
  final _logger = getLogger('PrintersEditViewModel');

  final _navigationService = locator<NavigationService>();
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();
  final _fbKey = GlobalKey<FormBuilderState>();
  final PrinterSetting printerSetting;
  late final webcams = printerSetting.cams.toList();
  late final tempPresets = printerSetting.temperaturePresets.toList();

  PrintersEditViewModel(this.printerSetting);

  GlobalKey get formKey => _fbKey;

  String get printerDisplayName => printerSetting.name;

  String? get printerApiKey => printerSetting.apiKey;

  String? get printerWsUrl => printerSetting.wsUrl;

  String? get printerHttpUrl => printerSetting.httpUrl;

  int get extruderMinTemperature =>
      printerSetting.printerService.printerStream.valueOrNull?.configFile
          .primaryExtruder?.minTemp
          .toInt() ??
      0;

  int get extruderMaxTemperature =>
      printerSetting.printerService.printerStream.valueOrNull?.configFile
          .primaryExtruder?.maxTemp
          .toInt() ??
      500;

  int get bedMinTemperature =>
      printerSetting.printerService.printerStream.valueOrNull?.configFile
          .configHeaterBed?.minTemp
          .toInt() ??
      0;

  int get bedMaxTemperature =>
      printerSetting.printerService.printerStream.valueOrNull?.configFile
          .configHeaterBed?.maxTemp
          .toInt() ??
      150;

  bool get printerInvertX => printerSetting.inverts[0];

  bool get printerInvertY => printerSetting.inverts[1];

  bool get printerInvertZ => printerSetting.inverts[2];

  int get printerSpeedXY => printerSetting.speedXY;

  int get printerSpeedZ => printerSetting.speedZ;

  int get printerExtruderFeedrate => printerSetting.extrudeFeedrate;

  onWebCamAdd() {
    WebcamSetting cam = WebcamSetting('New Webcam',
        'http://${Uri.parse(printerSetting.wsUrl).host}/webcam/?action=stream');
    webcams.add(cam);

    notifyListeners();
  }

  onWebCamRemove(WebcamSetting toRemoved) {
    webcams.remove(toRemoved);
    _saveAllCams();
    notifyListeners();
  }

  _saveAllCams() {
    webcams.forEach((element) {
      _saveCam(element);
    });
  }

  _saveCam(WebcamSetting toSave) {
    _fbKey.currentState?.save();
    var name = _fbKey.currentState!.value['${toSave.uuid}-camName'];
    var url = _fbKey.currentState!.value['${toSave.uuid}-camUrl'];
    var fH = _fbKey.currentState!.value['${toSave.uuid}-camFH'];
    var fV = _fbKey.currentState!.value['${toSave.uuid}-camFV'];
    if (name != null) toSave.name = name;
    if (url != null) toSave.url = url;
    if (fH != null) toSave.flipHorizontal = fH;
    if (fV != null) toSave.flipVertical = fV;
  }

  onTempPresetAdd() {
    TemperaturePreset preset = TemperaturePreset("New Preset");
    tempPresets.add(preset);

    notifyListeners();
  }

  onTempPresetRemove(TemperaturePreset toRemoved) {
    tempPresets.remove(toRemoved);
    _saveAllPresets();
    notifyListeners();
  }

  _saveAllPresets() {
    tempPresets.forEach((element) {
      _savePreset(element);
    });
  }

  _savePreset(TemperaturePreset toSave) {
    _fbKey.currentState?.save();
    var name = _fbKey.currentState!.value['${toSave.uuid}-presetName'];
    int? extruderTemp =
        _fbKey.currentState!.value['${toSave.uuid}-extruderTemp'];
    int? bedTemp = _fbKey.currentState!.value['${toSave.uuid}-bedTemp'];
    if (name != null) toSave.name = name;
    if (extruderTemp != null) toSave.extruderTemp = extruderTemp;
    if (bedTemp != null) toSave.bedTemp = bedTemp;
  }

  onFormConfirm() async {
    FormBuilderState currentState = _fbKey.currentState!;
    if (currentState.saveAndValidate()) {
      var printerName = currentState.value['printerName'];
      var printerAPIKey = currentState.value['printerApiKey'];
      var printerUrl = currentState.value['printerUrl'];
      var wsUrl = currentState.value['wsUrl'];

      List<bool> inverts = [
        currentState.value['invertX'],
        currentState.value['invertY'],
        currentState.value['invertZ']
      ];
      var speedXY = currentState.value['speedXY'];
      var speedZ = currentState.value['speedZ'];
      var extrudeSpeed = currentState.value['extrudeSpeed'];

      _saveAllCams();
      _saveAllPresets();
      printerSetting
        ..name = printerName
        ..wsUrl = wsUrl
        ..httpUrl = printerUrl
        ..apiKey = printerAPIKey
        ..cams = webcams
        ..temperaturePresets = tempPresets
        ..inverts = inverts
        ..speedXY = speedXY
        ..speedZ = speedZ
        ..extrudeFeedrate = extrudeSpeed;

      await _machineService.updateMachine(printerSetting);
      _navigationService.back();
    }
  }

  onDeleteTap() async {
    _dialogService
        .showConfirmationDialog(
      title: "Delete ${printerSetting.name}?",
      description:
          "Are you sure you want to remove the printer ${printerSetting.name} running under the address '$printerHttpUrl'?",
      confirmationTitle: "Delete",
    )
        .then((dialogResponse) {
      if (dialogResponse?.confirmed ?? false)
        _machineService.removeMachine(printerSetting).then(
            (value) => _navigationService.clearStackAndShow(Routes.overView));
    });
  }

  onPresetReorder(int oldIndex, int newIndex) {
    TemperaturePreset _row = tempPresets.removeAt(oldIndex);
    tempPresets.insert(newIndex, _row);
    notifyListeners();
  }

  onWebCamReorder(int oldIndex, int newIndex) {
    WebcamSetting _row = webcams.removeAt(oldIndex);
    webcams.insert(newIndex, _row);
    notifyListeners();
  }
}
