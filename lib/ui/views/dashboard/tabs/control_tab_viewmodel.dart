import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/domain/moonraker/gcode_macro.dart';
import 'package:mobileraker/domain/moonraker/machine_settings.dart';
import 'package:mobileraker/domain/moonraker/macro_group.dart';
import 'package:mobileraker/dto/config/config_output.dart';
import 'package:mobileraker/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/dto/machine/output_pin.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/components/dialog/editForm/range_edit_form_view.dart';
import 'package:mobileraker/ui/components/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';
const String _MachineSettingsStreamKey = 'machineSettings';

class ControlTabViewModel extends MultipleStreamViewModel {
  final _dialogService = locator<DialogService>();
  final _settingService = locator<SettingService>();
  final _selectedMachineService = locator<SelectedMachineService>();
  final _machineService = locator<MachineService>();

  int selectedIndexRetractLength = 0;

  MacroGroup? selectedGrp;

  ScrollController get fansScrollController => _fansScrollController;
  ScrollController _fansScrollController = new ScrollController(
    keepScrollOffset: true,
  );

  ScrollController get outputsScrollController => _outputsScrollController;
  ScrollController _outputsScrollController = new ScrollController(
    keepScrollOffset: true,
  );

  Machine? _machine;
  int _machineHashCode = -1;

  List<int> get retractLengths => machineSettings.extrudeSteps;

  int get fansSteps => 1 + printer.fans.length;

  int get outputSteps => printer.outputPins.length;

  List<MacroGroup> get macroGroups => machineSettings.macroGroups;

  PrinterService? get _printerService => _machine?.printerService;

  KlippyService? get _klippyService => _machine?.klippyService;

  bool get isMachineAvailable => dataReady(_SelectedPrinterStreamKey);

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get isServerAvailable => dataReady(_ServerStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get isPrinterAvailable => dataReady(_PrinterStreamKey);

  MachineSettings get machineSettings => dataMap![_MachineSettingsStreamKey];

  bool get isMachineSettingsAvailable => dataReady(_MachineSettingsStreamKey);

  bool get isPrinting => printer.print.state == PrintState.printing;

  bool get canUsePrinter => server.klippyState == KlipperState.ready;

  int get flowMultiplier {
    return (printer.gCodeMove.extrudeFactor * 100).toInt();
  }

  int get speedMultiplier {
    return (printer.gCodeMove.speedFactor * 100).toInt();
  }

  Set<NamedFan> get filteredFans => printer.fans
      .where((NamedFan element) => !element.name.startsWith('_'))
      .toSet();

  Set<OutputPin> get filteredPins => printer.outputPins
      .where((OutputPin element) => !element.name.startsWith('_'))
      .toSet();

  bool get isDataReady =>
      isPrinterAvailable &&
      isServerAvailable &&
      isMachineAvailable &&
      isMachineSettingsAvailable;

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<Machine?>(_selectedMachineService.selectedMachine),
        if (_machine != null) ...{
          _MachineSettingsStreamKey: StreamData<MachineSettings>(
              _machineService.fetchSettings(_machine!).asStream()),
          _PrinterStreamKey:
              StreamData<Printer>(_printerService!.printerStream),
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream)
        }
      };

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case _SelectedPrinterStreamKey:
        Machine? nmachine = data;
        if (nmachine == _machine && nmachine.hashCode == _machineHashCode)
          break;
        _machine = nmachine;
        _machineHashCode = nmachine.hashCode;
        notifySourceChanged(clearOldData: true);
        break;
      case _MachineSettingsStreamKey:
        if (machineSettings.macroGroups.isNotEmpty) {
          int idx = min(machineSettings.macroGroups.length-1,max(0, _settingService.readInt(selectedGCodeGrpIndex, 0)));
          selectedGrp = machineSettings.macroGroups[idx];
        }
        break;
      default:
        // Do nothing
        break;
    }
  }

  ConfigOutput? configForOutput(String name) {
    return printer.configFile.outputs[name];
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
        _printerService?.outputPin(pin.name, v.toDouble());
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
                max: 100, current: printer.printFan.speed * 100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        _printerService?.partCoolingFan(v.toDouble() / 100);
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
        _printerService?.genericFanFan(namedFan.name, v.toDouble() / 100);
      }
    });
  }

  onSelectedRetractChanged(int index) {
    selectedIndexRetractLength = index;
  }

  onRetractBtn() {
    var double = (retractLengths[selectedIndexRetractLength] * -1).toDouble();

    _printerService?.moveExtruder(
        double, machineSettings.extrudeFeedrate.toDouble());
  }

  onDeRetractBtn() {
    var double = (retractLengths[selectedIndexRetractLength]).toDouble();
    _printerService?.moveExtruder(
        double, machineSettings.extrudeFeedrate.toDouble());
  }

  onMacroPressed(GCodeMacro macro) {
    _printerService?.gCode(macro.name);
  }

  onMacroGroupSelected(MacroGroup? macroGroup) {
    if (macroGroup != null)
      _settingService.writeInt(
          selectedGCodeGrpIndex, macroGroups.indexOf(macroGroup));
    selectedGrp = macroGroup;
  }

  onEditSpeedMultiplier() {
    _dialogService
        .showCustomDialog(
            variant: DialogType.numEditForm,
            title: 'Edit Speed Multiplier in %',
            mainButtonTitle: 'Confirm',
            secondaryButtonTitle: 'Cancel',
            data: NumberEditDialogArguments(
                current: printer.gCodeMove.speedFactor * 100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        _printerService?.speedMultiplier(v.toInt());
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
                current: printer.gCodeMove.extrudeFactor * 100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        _printerService?.flowMultiplier(v.toInt());
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
