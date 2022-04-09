import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/domain/hive/gcode_macro.dart';
import 'package:mobileraker/domain/hive/macro_group.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/domain/hive/temperature_preset.dart';
import 'package:mobileraker/domain/hive/webcam_setting.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/ui/components/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/ui/components/snackbar/setup_snackbar.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/ui/components/dialog/importSettings/import_settings_view.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class PrintersEditViewModel extends MultipleFutureViewModel {
  final _logger = getLogger('PrintersEditViewModel');

  final _printerMapKey = 'printer';
  final _machinesMapKey = 'machines';

  final _navigationService = locator<NavigationService>();
  final _snackbarService = locator<SnackbarService>();
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();
  final _fbKey = GlobalKey<FormBuilderState>();
  final Machine machine;

  late final _macroGroups = machine.macroGroups.toList();

  late final webcams = machine.cams.toList();

  late final tempPresets = machine.temperaturePresets.toList();

  late final printerMoveSteps = machine.moveSteps.toList();

  late final printerBabySteps = machine.babySteps.toList();

  late final printerExtruderSteps = machine.extrudeSteps.toList();
  MacroGroup? srcGrpDragging;
  bool macroGroupAccepted = false;

  PrintersEditViewModel(this.machine);

  Printer get fetchedPrinter => dataMap![_printerMapKey];

  List<Machine> get fetchedMachines => dataMap![_machinesMapKey];

  bool get fetchingPrinter => busy(_printerMapKey);

  bool get fetchingMachines => busy(_machinesMapKey);

  @override
  Map<String, Future Function()> get futuresMap => {
        _printerMapKey: printerFuture,
        _machinesMapKey: machineFuture,
      };

  Future<Printer> printerFuture() {
    return machine.printerService.printerStream.first;
  }

  Future<List<Machine>> machineFuture() {
    return _machineService.fetchAll();
  }

  @override
  onData(String key) {
    if (key != _printerMapKey) return;

    MacroGroup defaultGroup = _defaultGroup;

    List<String> filteredMacros = fetchedPrinter.gcodeMacros
        .where((element) => !element.startsWith('_'))
        .toList();
    for (MacroGroup grp in _macroGroups) {
      for (GCodeMacro macro in grp.macros.toList(growable: false)) {
        bool wasInList = filteredMacros.remove(macro.name);
        if (!wasInList) grp.macros.remove(macro);
      }
    }
    List<GCodeMacro> modifiableList = defaultGroup.macros.toList();
    modifiableList.addAll(filteredMacros.map((e) => GCodeMacro(e)));
    defaultGroup.macros = modifiableList;
  }

  List<String> get printersMacros {
    if (!fetchingPrinter) {
      return fetchedPrinter.gcodeMacros;
    }
    return [];
  }

  List<MacroGroup> get macroGroups {
    return _macroGroups;
  }

  MacroGroup get _defaultGroup => _macroGroups
          .firstWhere((element) => element.name == 'Default', orElse: () {
        MacroGroup group = MacroGroup(name: 'Default');
        _macroGroups.add(group);
        return group;
      });

  GlobalKey get formKey => _fbKey;

  String get printerDisplayName => machine.name;

  String? get printerApiKey => machine.apiKey;

  String? get printerWsUrl => machine.wsUrl;

  String? get printerHttpUrl => machine.httpUrl;

  int get extruderMinTemperature =>
      machine.printerService.printerStream.valueOrNull?.configFile
          .primaryExtruder?.minTemp
          .toInt() ??
      0;

  int get extruderMaxTemperature =>
      machine.printerService.printerStream.valueOrNull?.configFile
          .primaryExtruder?.maxTemp
          .toInt() ??
      500;

  int get bedMinTemperature =>
      machine.printerService.printerStream.valueOrNull?.configFile
          .configHeaterBed?.minTemp
          .toInt() ??
      0;

  int get bedMaxTemperature =>
      machine.printerService.printerStream.valueOrNull?.configFile
          .configHeaterBed?.maxTemp
          .toInt() ??
      150;

  bool get printerInvertX => machine.inverts[0];

  bool get printerInvertY => machine.inverts[1];

  bool get printerInvertZ => machine.inverts[2];

  int get printerSpeedXY => machine.speedXY;

  int get printerSpeedZ => machine.speedZ;

  int get printerExtruderFeedrate => machine.extrudeFeedrate;

  bool get canShowImportSettings =>
      !fetchingPrinter && fetchedMachines.length > 1;

  bool isDefaultMacroGrp(MacroGroup macroGroup) {
    return macroGroup == _defaultGroup;
  }

  removeExtruderStep(int step) {
    printerExtruderSteps.remove(step);
    notifyListeners();
  }

  addExtruderStep(String rawValue) {
    int? nStep = int.tryParse(rawValue);

    if (nStep == null) {
      _snackbarService.showCustomSnackBar(
          variant: SnackbarType.error,
          duration: const Duration(seconds: 5),
          title: 'Extruder-Steps',
          message: "Can not parse input");
    } else {
      if (printerExtruderSteps.contains(nStep)) {
        _snackbarService.showCustomSnackBar(
            variant: SnackbarType.error,
            duration: const Duration(seconds: 5),
            title: 'Extruder-Steps',
            message: 'Step already present!');
      } else {
        printerExtruderSteps.add(nStep);
        printerExtruderSteps.sort();
        notifyListeners();
      }
    }
  }

  removeBabyStep(double step) {
    printerBabySteps.remove(step);
    notifyListeners();
  }

  addBabyStep(String rawValue) {
    double? nStep = double.tryParse(rawValue);

    if (nStep == null) {
      _snackbarService.showCustomSnackBar(
          variant: SnackbarType.error,
          duration: const Duration(seconds: 5),
          title: 'Babystepping-Steps',
          message: "Can not parse input");
    } else {
      if (printerBabySteps.contains(nStep)) {
        _snackbarService.showCustomSnackBar(
            variant: SnackbarType.error,
            duration: const Duration(seconds: 5),
            title: 'Babystepping-Steps',
            message: "Can not parse input");
      } else {
        printerBabySteps.add(nStep);
        printerBabySteps.sort();
        notifyListeners();
      }
    }
  }

  removeMoveStep(int step) {
    printerMoveSteps.remove(step);
    notifyListeners();
  }

  addMoveStep(String rawValue) {
    int? nStep = int.tryParse(rawValue);

    if (nStep == null) {
      _snackbarService.showCustomSnackBar(
          variant: SnackbarType.error,
          duration: const Duration(seconds: 5),
          title: 'Move-Steps',
          message: "Can not parse input");
    } else {
      if (printerMoveSteps.contains(nStep)) {
        _snackbarService.showCustomSnackBar(
            variant: SnackbarType.error,
            duration: const Duration(seconds: 5),
            title: 'Move-Steps',
            message: "Step already present!");
      } else {
        printerMoveSteps.add(nStep);
        printerMoveSteps.sort();
        notifyListeners();
      }
    }
  }

  onMacroGroupAdd() {
    MacroGroup group = MacroGroup(name: 'New Group', macros: []);
    _macroGroups.add(group);
    _saveAllGroupStuff();
    notifyListeners();
  }

  onMacroGroupRemove(MacroGroup group) {
    _macroGroups.remove(group);
    if (group.macros.isNotEmpty) {
      _snackbarService.showSnackbar(message: plural('pages.printer_edit.macros.macros_to_default',group.macros.length));
      _defaultGroup.macros.addAll(group.macros);
    }
    _saveAllGroupStuff();
    notifyListeners();
  }

  _saveAllMacroGroups() {
    macroGroups.forEach((element) => _saveMacroGroup(element));
  }

  _saveMacroGroup(MacroGroup toSave) {
    _fbKey.currentState?.save();
    var name = _fbKey.currentState!.value['${toSave.uuid}-macroName'];
    if (name != null) toSave.name = name;
  }

  onWebCamAdd() {
    WebcamSetting cam = WebcamSetting('New Webcam',
        'http://${Uri.parse(machine.wsUrl).host}/webcam/?action=stream');
    webcams.add(cam);
    _saveAllGroupStuff();
    notifyListeners();
  }

  onWebCamRemove(WebcamSetting toRemoved) {
    webcams.remove(toRemoved);
    _saveAllGroupStuff();
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
    var tFps = _fbKey.currentState!.value['${toSave.uuid}-tFps'];
    if (name != null) toSave.name = name;
    if (url != null) toSave.url = url;
    if (fH != null) toSave.flipHorizontal = fH;
    if (fV != null) toSave.flipVertical = fV;
    if (fV != null) toSave.targetFps = tFps;
  }

  onTempPresetAdd() {
    TemperaturePreset preset = TemperaturePreset("New Preset");
    tempPresets.add(preset);
    _saveAllMacroGroups();
    _saveAllPresets();
    _saveAllCams();
    notifyListeners();
  }

  onTempPresetRemove(TemperaturePreset toRemoved) {
    tempPresets.remove(toRemoved);
    _saveAllMacroGroups();
    _saveAllPresets();
    _saveAllCams();
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
      _saveAllGroupStuff();
      machine
        ..name = printerName
        ..wsUrl = wsUrl
        ..httpUrl = printerUrl
        ..apiKey = printerAPIKey
        ..cams = webcams
        ..temperaturePresets = tempPresets
        ..inverts = inverts
        ..speedXY = speedXY
        ..speedZ = speedZ
        ..extrudeFeedrate = extrudeSpeed
        ..moveSteps = printerMoveSteps
        ..babySteps = printerBabySteps
        ..macroGroups = macroGroups
        ..extrudeSteps = printerExtruderSteps;

      await _machineService.updateMachine(machine);
      if (StackedService.navigatorKey?.currentState?.canPop() ?? false) {
        _navigationService.back();
      } else {
        _navigationService.clearStackAndShow(Routes.dashboardView);
      }
    }
  }

  _saveAllGroupStuff() {
    _saveAllMacroGroups();
    _saveAllCams();
    _saveAllPresets();
  }

  onDeleteTap() async {
    _dialogService
        .showConfirmationDialog(
      title: "Delete ${machine.name}?",
      description:
          "Are you sure you want to remove the printer ${machine.name} running under the address '$printerHttpUrl'?",
      confirmationTitle: "Delete",
    )
        .then((dialogResponse) {
      if (dialogResponse?.confirmed ?? false)
        _machineService.removeMachine(machine).then(
            (value) => _navigationService.clearStackAndShow(Routes.dashboardView));
    });
  }

  onPresetReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    TemperaturePreset _row = tempPresets.removeAt(oldIndex);
    tempPresets.insert(newIndex, _row);
    notifyListeners();
  }

  onWebCamReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    WebcamSetting _row = webcams.removeAt(oldIndex);
    webcams.insert(newIndex, _row);
    notifyListeners();
  }

  onImportSettings() {
    _dialogService
        .showCustomDialog(
            variant: DialogType.importSettings,
            title: 'Copy Settings',
            mainButtonTitle: 'Copy',
            secondaryButtonTitle: 'Cancle',
            data: machine)
        .then(onImportSettingsReturns);
  }

  onImportSettingsReturns(DialogResponse? response) {
    if (response != null && response.confirmed) {
      FormBuilderState currentState = _fbKey.currentState!;
      ImportSettingsDialogViewResults result = response.data;
      Machine src = result.source;
      Map<String, dynamic> patchingValues = {};
      for (String field in result.fields) {
        switch (field) {
          case 'invertX':
            patchingValues[field] = src.inverts[0];
            break;
          case 'invertY':
            patchingValues[field] = src.inverts[1];
            break;
          case 'invertZ':
            patchingValues[field] = src.inverts[2];
            break;
          case 'speedXY':
            patchingValues[field] = src.speedXY.toString();
            break;
          case 'speedZ':
            patchingValues[field] = src.speedZ.toString();
            break;
          case 'extrudeSpeed':
            patchingValues[field] = src.extrudeFeedrate.toString();
            break;
          case 'moveSteps':
            printerMoveSteps.clear();
            printerMoveSteps.addAll(src.moveSteps);

            break;
          case 'babySteps':
            printerBabySteps.clear();
            printerBabySteps.addAll(src.babySteps);
            break;
          case 'extrudeSteps':
            printerExtruderSteps.clear();
            printerExtruderSteps.addAll(src.extrudeSteps);
            break;
        }
      }
      currentState.patchValue(patchingValues);
      tempPresets.addAll(result.presets);
      notifyListeners();
    }
  }

  onGCodeDragReordered(int oldIndex, int newIndex) {
    if (macroGroupAccepted) {
      _logger.i("On drag reordered - CANCEL (macroGroupAccepted)");
      return;
    }

    _logger.i("On drag reordered");
    GCodeMacro gCodeMacro = srcGrpDragging!.macros.removeAt(oldIndex);
    srcGrpDragging!.macros.insert(newIndex, gCodeMacro);
    notifyListeners();
  }

  onGCodeDragStart(MacroGroup srcGrp) {
    _logger.i("On drag started from ${srcGrp.name}");
    srcGrpDragging = srcGrp;
    macroGroupAccepted = false;
  }

  onGCodeDragAccepted(MacroGroup newGroup, int index) {
    if (newGroup == srcGrpDragging) {
      _logger.d("GCode-Drag NOT accepted (SAME GRP)");
      return;
    }
    GCodeMacro macro = srcGrpDragging!.macros[index];
    _logger.d("GCode-Drag accepted ${macro.name} in ${newGroup.name}");
    macroGroupAccepted = true;
    newGroup.macros.add(macro);
    srcGrpDragging!.macros.remove(macro);
    notifyListeners();
  }

  openQrScanner() async {
    var readValue = await _navigationService.navigateTo(Routes.qrScannerView);
    if (readValue != null) {
      _fbKey.currentState?.fields['printerApiKey']?.didChange(readValue);
    }
    // printerApiKey = resu;
  }
}
