import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/data/dto/config/config_output.dart';
import 'package:mobileraker/data/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/data/dto/machine/output_pin.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/moonraker_db/gcode_macro.dart';
import 'package:mobileraker/data/model/moonraker_db/macro_group.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/common/mixins/klippy_mixin.dart';
import 'package:mobileraker/ui/common/mixins/machine_settings_mixin.dart';
import 'package:mobileraker/ui/common/mixins/printer_mixin.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_viewmodel.dart';
import 'package:mobileraker/ui/components/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ControlTabViewModel extends MultipleStreamViewModel
    with SelectedMachineMixin, PrinterMixin, KlippyMixin, MachineSettingsMixin {
  final _dialogService = locator<DialogService>();
  final _settingService = locator<SettingService>();

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

  bool get isPrinting => printerData.print.state == PrintState.printing;

  int get flowMultiplier {
    return (printerData.gCodeMove.extrudeFactor * 100).toInt();
  }

  int get speedMultiplier {
    return (printerData.gCodeMove.speedFactor * 100).toInt();
  }

  bool get extruderCanExtrude =>
      printerData.extruderFromIndex(activeExtruder).temperature >=
      (printerData.configFile.extruderForIndex(activeExtruder)?.minExtrudeTemp ?? 170);

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

  onEditSpeedMultiplier() {
    _dialogService
        .showCustomDialog(
            variant: DialogType.numEditForm,
            title: 'Edit Speed Multiplier in %',
            mainButtonTitle: 'Confirm',
            secondaryButtonTitle: 'Cancel',
            data: NumberEditDialogArguments(
                current: printerData.gCodeMove.speedFactor * 100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        printerService.speedMultiplier(v.toInt());
      }
    });
  }

  onEditFlowMultiplier() {
    _dialogService
        .showCustomDialog(
            variant: DialogType.numEditForm,
            title: 'Edit Flow Multiplier in %',
            mainButtonTitle: 'Confirm',
            secondaryButtonTitle: 'Cancel',
            data: NumberEditDialogArguments(
                current: printerData.gCodeMove.extrudeFactor * 100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        printerService.flowMultiplier(v.toInt());
      }
    });
  }

  @override
  dispose() {
    super.dispose();
    _fansScrollController.dispose();
    _outputsScrollController.dispose();
  }
}
