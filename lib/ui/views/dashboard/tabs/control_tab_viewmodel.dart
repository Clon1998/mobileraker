import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/hive/gcode_macro.dart';
import 'package:mobileraker/domain/hive/macro_group.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/dto/config/config_output.dart';
import 'package:mobileraker/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/dto/machine/output_pin.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/ui/components/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/components/dialog/editForm/range_edit_form_view.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';

class ControlTabViewModel extends MultipleStreamViewModel {
  final _dialogService = locator<DialogService>();
  final _settingService = locator<SettingService>();
  final _machineService = locator<MachineService>();

  int selectedIndexRetractLength = 0;

  MacroGroup? selectedGrp;

  Machine? _machine;
  PrinterService? _printerService;
  KlippyService? _klippyService;

  ScrollController _fansScrollController = new ScrollController(
    keepScrollOffset: true,
  );

  ScrollController get fansScrollController => _fansScrollController;

  ScrollController _outputsScrollController = new ScrollController(
    keepScrollOffset: true,
  );

  ScrollController get outputsScrollController => _outputsScrollController;

  List<int> get retractLengths {
    return _machine?.extrudeSteps.toList() ?? const [1, 10, 25, 50];
  }

  int get fansSteps => 1 + printer.fans.length;

  int get outputSteps => printer.outputPins.length;

  List<MacroGroup> get macroGroups {
    return _machine?.macroGroups ?? [];
  }

  //ToDO: Maybe to pass these down from the overview viewmodel..
  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<Machine?>(_machineService.selectedMachine),
        if (_machine?.printerService != null) ...{
          _PrinterStreamKey: StreamData<Printer>(_printerService!.printerStream)
        },
        if (_machine?.klippyService != null) ...{
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
        if (nmachine == _machine) break;
        _machine = nmachine;

        if (nmachine?.printerService != null) {
          _printerService = nmachine?.printerService;
        }

        if (nmachine?.klippyService != null) {
          _klippyService = nmachine?.klippyService;
        }
        if (nmachine?.macroGroups.isNotEmpty ?? false)
          selectedGrp = nmachine!.macroGroups.first;
        else
          selectedGrp = null;
        notifySourceChanged(clearOldData: true);
        break;
      default:
        // Do nothing
        break;
    }
  }

  bool get isMachineAvailable => dataReady(_SelectedPrinterStreamKey);

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get isServerAvailable => dataReady(_ServerStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get isPrinterAvailable => dataReady(_PrinterStreamKey);

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
        double, _machine!.extrudeFeedrate.toDouble());
  }

  onDeRetractBtn() {
    var double = (retractLengths[selectedIndexRetractLength]).toDouble();
    _printerService?.moveExtruder(
        double, _machine!.extrudeFeedrate.toDouble());
  }

  onMacroPressed(GCodeMacro macro) {
    _printerService?.gCode(macro.name);
  }

  onMacroGroupSelected(MacroGroup? macroGroup) {
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
