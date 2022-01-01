import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/gcode_macro.dart';
import 'package:mobileraker/domain/macro_group.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/dto/config/config_output.dart';
import 'package:mobileraker/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/dto/machine/output_pin.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/enums/dialog_type.dart';
import 'package:mobileraker/service/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:mobileraker/ui/dialog/editForm/num_edit_form_view.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';

class ControlTabViewModel extends MultipleStreamViewModel {
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();

  int selectedIndexRetractLength = 0;

  MacroGroup? selectedGrp;

  PrinterSetting? _printerSetting;
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
    return _printerSetting?.extrudeSteps.toList() ?? const [1, 10, 25, 50];
  }

  int get fansSteps => 1 + printer.fans.length;

  int get outputSteps => printer.outputPins.length;

  List<MacroGroup> get macroGroups {
    return _printerSetting?.macroGroups ?? [];
  }

  //ToDO: Maybe to pass these down from the overview viewmodel..
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
        if (nPrinterSetting == _printerSetting) break;
        _printerSetting = nPrinterSetting;

        if (nPrinterSetting?.printerService != null) {
          _printerService = nPrinterSetting?.printerService;
        }

        if (nPrinterSetting?.klippyService != null) {
          _klippyService = nPrinterSetting?.klippyService;
        }
        if (nPrinterSetting?.macroGroups.isNotEmpty ?? false)
          selectedGrp = nPrinterSetting!.macroGroups.first;
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

  Set<NamedFan> get filteredFans => printer.fans
      .where((NamedFan element) => !element.name.startsWith("_"))
      .toSet();

  Set<OutputPin> get filteredPins => printer.outputPins
      .where((OutputPin element) => !element.name.startsWith("_"))
      .toSet();

  ConfigOutput? configForOutput(String name) {
    return printer.configFile.outputs[name];
  }

  onEditPin(OutputPin pin, ConfigOutput? configOutput) {
    int fractionToShow = (configOutput == null || !configOutput.pwm) ? 0 : 2;
    _dialogService
        .showCustomDialog(
            variant: DialogType.numEditForm,
            title: "Edit ${beautifyName(pin.name)} value!",
            mainButtonTitle: "Confirm",
            secondaryButtonTitle: "Cancel",
            data: NumEditFormDialogViewArguments(
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
    _dialogService
        .showCustomDialog(
            variant: DialogType.numEditForm,
            title: "Edit Part Cooling fan %",
            mainButtonTitle: "Confirm",
            secondaryButtonTitle: "Cancel",
            data: NumEditFormDialogViewArguments(
                max: 100, current: printer.printFan.speed * 100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        _printerService?.partCoolingFan(v.toDouble() / 100);
      }
    });
  }

  onEditGenericFan(NamedFan namedFan) {
    _dialogService
        .showCustomDialog(
            variant: DialogType.numEditForm,
            title: "Edit ${beautifyName(namedFan.name)} %",
            mainButtonTitle: "Confirm",
            secondaryButtonTitle: "Cancel",
            data: NumEditFormDialogViewArguments(
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
        double, _printerSetting!.extrudeFeedrate.toDouble());
  }

  onDeRetractBtn() {
    var double = (retractLengths[selectedIndexRetractLength]).toDouble();
    _printerService?.moveExtruder(
        double, _printerSetting!.extrudeFeedrate.toDouble());
  }

  onMacroPressed(GCodeMacro macro) {
    _printerService?.gCodeMacro(macro.name);
  }

  onMacroGroupSelected(MacroGroup? macroGroup) {
    selectedGrp = macroGroup;
  }

  @override
  void dispose() {
    super.dispose();
    _fansScrollController.dispose();
    _outputsScrollController.dispose();
  }
}
