import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/model/hive/machine.dart';
import 'package:mobileraker/model/hive/webcam_setting.dart';
import 'package:mobileraker/model/moonraker/gcode_macro.dart';
import 'package:mobileraker/model/moonraker/machine_settings.dart';
import 'package:mobileraker/model/moonraker/macro_group.dart';
import 'package:mobileraker/model/moonraker/temperature_preset.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/ui/components/dialog/importSettings/import_settings_view.dart';
import 'package:mobileraker/ui/components/dialog/importSettings/import_settings_viewmodel.dart';
import 'package:mobileraker/ui/components/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/ui/components/snackbar/setup_snackbar.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const _PrinterMapKey = 'printer';
const _MachinesMapKey = 'machines';
const _MachineSettingsMapKey = 'machineSettings';

class PrinterEditViewModel extends MultipleFutureViewModel {
  PrinterEditViewModel(this.machine) : webcams = machine.cams.toList();

  final Machine machine;

  final List<WebcamSetting> webcams;

  List<TemperaturePreset> get tempPresets => machineSettings.temperaturePresets;

  List<int> get printerMoveSteps => machineSettings.moveSteps;

  List<double> get printerBabySteps => machineSettings.babySteps;

  List<int> get printerExtruderSteps => machineSettings.extrudeSteps;

  List<MacroGroup> get macroGroups => _macroGroups;
  final List<MacroGroup> _macroGroups = [];

  final _logger = getLogger('PrintersEditViewModel');
  final _navigationService = locator<NavigationService>();
  final _snackbarService = locator<SnackbarService>();
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();

  GlobalKey get formKey => _fbKey;
  final _fbKey = GlobalKey<FormBuilderState>();

  MacroGroup? srcGrpDragging;
  bool macroGroupAccepted = false;

  MachineSettings get machineSettings => dataMap![_MachineSettingsMapKey];

  Printer get fetchedPrinter => dataMap![_PrinterMapKey];

  List<Machine> get fetchedMachines => dataMap![_MachinesMapKey];

  bool get isFetchingSettings => busy(_MachineSettingsMapKey);

  bool get isFetchingPrinter => busy(_PrinterMapKey);

  bool get isFetchingMachines => busy(_MachinesMapKey);

  bool get settingsHasError => hasErrorForKey(_MachineSettingsMapKey);

  bool get printerHasError => hasErrorForKey(_PrinterMapKey);

  bool get machinesHasError => hasErrorForKey(_MachinesMapKey);

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

  bool get canShowImportSettings =>
      !isFetchingPrinter && fetchedMachines.length > 1;

  MacroGroup get _defaultGroup => _macroGroups
          .firstWhere((element) => element.name == 'Default', orElse: () {
        MacroGroup group = MacroGroup(name: 'Default');
        _macroGroups.add(group);
        return group;
      });

  Future<Printer> _printerFuture() =>
      machine.printerService.printerStream.first;

  Future<List<Machine>> _machineListFuture() => _machineService.fetchAll();

  Future<MachineSettings> _machineSettingsFuture() =>
      _machineService.fetchSettings(machine);


  @override
  void onFutureError(dynamic error, Object? key) {
    _logger.e("Error on $key: $error");
  }

  @override
  Map<String, Future Function()> get futuresMap => {
        _PrinterMapKey: _printerFuture,
        _MachinesMapKey: _machineListFuture,
        _MachineSettingsMapKey: _machineSettingsFuture
      };

  @override
  onData(String key) {
    super.onData(key);
    if (!isFetchingPrinter && !isFetchingSettings) _buildMacroGroups();
  }

  bool isDefaultMacroGrp(MacroGroup macroGroup) {
    return macroGroup == _defaultGroup;
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

  removeExtruderStep(int step) {
    printerExtruderSteps.remove(step);
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

  removeBabyStep(double step) {
    printerBabySteps.remove(step);
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

  removeMoveStep(int step) {
    printerMoveSteps.remove(step);
    notifyListeners();
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
      _snackbarService.showSnackbar(
          message: plural('pages.printer_edit.macros.macros_to_default',
              group.macros.length));
      _defaultGroup.macros.addAll(group.macros);
    }
    _saveAllGroupStuff();
    notifyListeners();
  }

  onTempPresetAdd() {
    TemperaturePreset preset = TemperaturePreset(name: "New Preset");
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

  onFormConfirm() async {
    FormBuilderState currentState = _fbKey.currentState!;
    if (currentState.saveAndValidate()) {
      var printerName = currentState.value['printerName'];
      var printerAPIKey = currentState.value['printerApiKey'];
      var printerUrl = currentState.value['printerUrl'];
      var wsUrl = currentState.value['wsUrl'];


      _saveAllGroupStuff();

      machine
        ..name = printerName
        ..wsUrl = wsUrl
        ..httpUrl = printerUrl
        ..apiKey = printerAPIKey
        ..cams = webcams;
      //   ..temperaturePresets = tempPresets
      //   ..inverts = inverts
      //   ..speedXY = speedXY
      //   ..speedZ = speedZ
      //   ..extrudeFeedrate = extrudeSpeed
      //   ..moveSteps = printerMoveSteps
      //   ..babySteps = printerBabySteps
      //   ..macroGroups = macroGroups
      //   ..extrudeSteps = printerExtruderSteps;
      await _machineService.updateMachine(machine);

      if (!settingsHasError &&
          !printerHasError &&
          !isFetchingPrinter &&
          !isFetchingSettings) {
        List<bool> inverts = [
          currentState.value['invertX'],
          currentState.value['invertY'],
          currentState.value['invertZ']
        ];
        var speedXY = currentState.value['speedXY'];
        var speedZ = currentState.value['speedZ'];
        var extrudeSpeed = currentState.value['extrudeSpeed'];

        await _machineService.updateSettings(machine, MachineSettings(
            created: machineSettings.created,
            lastModified: DateTime.now(),
            macroGroups: _macroGroups,
            temperaturePresets: tempPresets,
            babySteps: printerBabySteps,
            extrudeSteps: printerExtruderSteps,
            moveSteps: printerMoveSteps,
            extrudeFeedrate: extrudeSpeed,
            inverts: inverts,
            speedXY: speedXY,
            speedZ: speedZ));
      }
      if (StackedService.navigatorKey?.currentState?.canPop() ?? false) {
        _navigationService.back();
      } else {
        _navigationService.clearStackAndShow(Routes.dashboardView);
      }
    }
  }

  onMachineDeleteTap() async {
    _dialogService
        .showConfirmationDialog(
      title: "Delete ${machine.name}?",
      description:
          "Are you sure you want to remove the printer ${machine.name} running under the address '${machine.httpUrl}'?",
      confirmationTitle: "Delete",
    )
        .then((dialogResponse) {
      if (dialogResponse?.confirmed ?? false)
        _machineService.removeMachine(machine).then((value) =>
            _navigationService.clearStackAndShow(Routes.dashboardView));
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

  onImportSettings(MaterialLocalizations materialLocalizations) {
    _dialogService
        .showCustomDialog(
            variant: DialogType.importSettings,
            title: 'Copy Settings',
            mainButtonTitle: materialLocalizations.copyButtonLabel,
            secondaryButtonTitle: materialLocalizations.cancelButtonLabel.capitalizeFirst,
            data: machine)
        .then(onImportSettingsReturns);
  }

  onImportSettingsReturns(DialogResponse? response) {
    if (response != null && response.confirmed) {
      FormBuilderState currentState = _fbKey.currentState!;
      ImportSettingsDialogViewResults result = response.data;
      ImportMachineSettingsDto importDto = result.source;
      MachineSettings settings  = importDto.machineSettings;
      Map<String, dynamic> patchingValues = {};
      for (String field in result.fields) {
        switch (field) {
          case 'invertX':
            patchingValues[field] = settings.inverts[0];
            break;
          case 'invertY':
            patchingValues[field] = settings.inverts[1];
            break;
          case 'invertZ':
            patchingValues[field] = settings.inverts[2];
            break;
          case 'speedXY':
            patchingValues[field] = settings.speedXY.toString();
            break;
          case 'speedZ':
            patchingValues[field] = settings.speedZ.toString();
            break;
          case 'extrudeSpeed':
            patchingValues[field] = settings.extrudeFeedrate.toString();
            break;
          case 'moveSteps':
            printerMoveSteps.clear();
            printerMoveSteps.addAll(settings.moveSteps);

            break;
          case 'babySteps':
            printerBabySteps.clear();
            printerBabySteps.addAll(settings.babySteps);
            break;
          case 'extrudeSteps':
            printerExtruderSteps.clear();
            printerExtruderSteps.addAll(settings.extrudeSteps);
            break;
        }
      }
      currentState.patchValue(patchingValues);
      // tempPresets.addAll(result.presets);
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

  _buildMacroGroups() {
    _macroGroups.addAll(machineSettings.macroGroups);
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
    modifiableList.addAll(filteredMacros.map((e) => GCodeMacro(name: e)));
    defaultGroup.macros = modifiableList;
  }

  _saveAllMacroGroups() {
    if (isFetchingSettings)
      return;
    macroGroups.forEach((element) => _saveMacroGroup(element));
  }

  _saveMacroGroup(MacroGroup toSave) {
    _fbKey.currentState?.save();
    var name = _fbKey.currentState!.value['${toSave.uuid}-macroName'];
    if (name != null)
      toSave
        ..name = name
        ..lastModified = DateTime.now();
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

  _saveAllPresets() {
    if (isFetchingSettings || settingsHasError)
      return;
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
    if ((bedTemp ?? extruderTemp ?? name ?? extruderTemp) != null)
      toSave.lastModified = DateTime.now();
  }

  _saveAllGroupStuff() {
    _saveAllMacroGroups();
    _saveAllCams();
    _saveAllPresets();
  }
}
