import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/data/dto/config/config_output.dart';
import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/data/dto/machine/output_pin.dart';
import 'package:mobileraker/data/model/moonraker_db/gcode_macro.dart';
import 'package:mobileraker/data/model/moonraker_db/macro_group.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/common/mixins/klippy_mixin.dart';
import 'package:mobileraker/ui/common/mixins/machine_settings_mixin.dart';
import 'package:mobileraker/ui/common/mixins/printer_mixin.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_viewmodel.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ControlTabViewModel extends MultipleStreamViewModel
    with SelectedMachineMixin, PrinterMixin, KlippyMixin, MachineSettingsMixin {
  final _dialogService = locator<DialogService>();
  final _settingService = locator<SettingService>();


  bool multipliersLocked = true;

  bool limitsLocked = true;

  int selectedIndexRetractLength = 0;

  int get activeExtruder {
    String? activeIdx = printerData.toolhead.activeExtruder?.substring(8);
    if (activeIdx != null) return int.tryParse(activeIdx) ?? 0;
    return 0;
  }

  MacroGroup? _selectedGrp;

  MacroGroup? get selectedGrp {
    if (machineSettings.macroGroups.isNotEmpty) {
      int idx = min(machineSettings.macroGroups.length - 1,
          max(0, _settingService.readInt(selectedGCodeGrpIndex, 0)));
      _selectedGrp = machineSettings.macroGroups[idx];
      return _selectedGrp;
    }
    return null;
  }

  set selectedGrp(MacroGroup? grp) => _selectedGrp = grp;

  ScrollController get fansScrollController => _fansScrollController;
  ScrollController _fansScrollController = new ScrollController(
    keepScrollOffset: true,
  );

  ScrollController get outputsScrollController => _outputsScrollController;
  ScrollController _outputsScrollController = new ScrollController(
    keepScrollOffset: true,
  );

  List<int> get retractLengths => machineSettings.extrudeSteps;

  int get fansSteps => 1 + printerData.fans.length;

  int get outputSteps => printerData.outputPins.length;

  List<MacroGroup> get macroGroups => machineSettings.macroGroups;

  double get flowMultiplier => printerData.gCodeMove.extrudeFactor;

  double get speedMultiplier => printerData.gCodeMove.speedFactor;

  double get pressureAdvanced => printerData.extruder.pressureAdvance;

  double get smoothTime => printerData.extruder.smoothTime;

  double get maxVelocity => printerData.toolhead.maxVelocity ?? 0;

  double get maxAccel => printerData.toolhead.maxAccel ?? 0;

  double get maxAccelToDecel => printerData.toolhead.maxAccelToDecel ?? 0;

  double get squareCornerVelocity =>
      printerData.toolhead.squareCornerVelocity ?? 0;

  double get extruderMinTemp => (printerData.configFile
          .extruderForIndex(activeExtruder)
          ?.minExtrudeTemp ??
      170);

  bool get extruderCanExtrude =>
      printerData.extruderFromIndex(activeExtruder).temperature >=
      extruderMinTemp;

  Set<NamedFan> get filteredFans => printerData.fans
      .where((NamedFan element) => !element.name.startsWith('_'))
      .toSet();

  Set<OutputPin> get filteredPins => printerData.outputPins
      .where((OutputPin element) => !element.name.startsWith('_'))
      .toSet();

  bool get isDataReady =>
      isSelectedMachineReady &&
      isPrinterDataReady &&
      isKlippyInstanceReady &&
      isMachineSettingsReady;

  ConfigOutput? configForOutput(String name) {
    return printerData.configFile.outputs[name];
  }

  onToggleMultipliersLock() {
    multipliersLocked = !multipliersLocked;
  }

  onToggleLimitLock() {
    limitsLocked = !limitsLocked;
  }

  onEditPin(OutputPin pin, ConfigOutput? configOutput) {
    int fractionToShow = (configOutput == null || !configOutput.pwm) ? 0 : 2;

    numberOrRangeDialog(
            dialogService: _dialogService,
            settingService: _settingService,
            title: 'Edit ${beautifyName(pin.name)} value!',
            mainButtonTitle: 'Confirm',
            secondaryButtonTitle: 'Cancel',
            data: NumberEditDialogArguments(
                max: configOutput?.scale.toInt() ?? 1,
                current: pin.value * (configOutput?.scale ?? 1),
                fraction: fractionToShow))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        printerService.outputPin(pin.name, v.toDouble());
      }
    });
  }

  onEditPartFan() {
    numberOrRangeDialog(
            dialogService: _dialogService,
            settingService: _settingService,
            title: 'Edit Part Cooling fan %',
            mainButtonTitle: 'Confirm',
            secondaryButtonTitle: 'Cancel',
            data: NumberEditDialogArguments(
                max: 100, current: printerData.printFan.speed * 100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        printerService.partCoolingFan(v.toDouble() / 100);
      }
    });
  }

  onEditGenericFan(NamedFan namedFan) {
    numberOrRangeDialog(
            dialogService: _dialogService,
            settingService: _settingService,
            title: 'Edit ${beautifyName(namedFan.name)} %',
            mainButtonTitle: 'Confirm',
            secondaryButtonTitle: 'Cancel',
            data: NumberEditDialogArguments(
                max: 100, current: namedFan.speed * 100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        printerService.genericFanFan(namedFan.name, v.toDouble() / 100);
      }
    });
  }

  onSelectedRetractChanged(int index) {
    selectedIndexRetractLength = index;
  }

  onRetractBtn() {
    var double = (retractLengths[selectedIndexRetractLength] * -1).toDouble();

    printerService.moveExtruder(
        double, machineSettings.extrudeFeedrate.toDouble());
  }

  onDeRetractBtn() {
    var double = (retractLengths[selectedIndexRetractLength]).toDouble();
    printerService.moveExtruder(
        double, machineSettings.extrudeFeedrate.toDouble());
  }

  onMacroPressed(GCodeMacro macro) {
    printerService.gCode(macro.name);
  }

  onMacroGroupSelected(MacroGroup? macroGroup) {
    if (macroGroup != null)
      _settingService.writeInt(
          selectedGCodeGrpIndex, macroGroups.indexOf(macroGroup));
    selectedGrp = macroGroup;
  }

  onExtruderSelected(int? idx) {
    if (idx != null) printerService.activateExtruder(idx);
  }

  onEditedSpeedMultiplier(double perc) {
    printerService.speedMultiplier((perc * 100).toInt());
  }

  onEditedFlowMultiplier(double perc) {
    printerService.flowMultiplier((perc * 100).toInt());
  }

  onEditedPressureAdvanced(double perc) {
    printerService.pressureAdvance(perc);
  }

  onEditedSmoothTime(double perc) {
    printerService.smoothTime(perc);
  }

  onEditedMaxVelocity(double vel) {
    printerService.setVelocityLimit(vel.toInt());
  }

  onEditedMaxAccel(double accel) {
    printerService.setAccelerationLimit(accel.toInt());
  }

  onEditedMaxAccelToDecel(double accelToDecel) {
    printerService.setAccelToDecel(accelToDecel.toInt());
  }

  onEditedMaxSquareCornerVelocity(double scv) {
    printerService.setSquareCornerVelocityLimit(scv);
  }

  @override
  dispose() {
    super.dispose();
    _fansScrollController.dispose();
    _outputsScrollController.dispose();
  }
}
