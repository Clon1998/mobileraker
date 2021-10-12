import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/dto/config/config_output.dart';
import 'package:mobileraker/dto/machine/fans/named_fan.dart';
import 'package:mobileraker/dto/machine/output_pin.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/server/klipper.dart';

import 'package:mobileraker/enums/dialog_type.dart';
import 'package:mobileraker/service/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:mobileraker/ui/dialog/editForm/editForm_view.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';

class ControlTabViewModel extends MultipleStreamViewModel {
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();

  List<int> retractLengths = [1, 10, 25, 50];

  int selectedIndexRetractLength = 0;

  PrinterSetting? _printerSetting;
  PrinterService? _printerService;
  KlippyService? _klippyService;

  //ToDO: Maybe to pass these down from the overview viewmodel..
  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<PrinterSetting?>(_machineService.selectedPrinter),
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
        notifySourceChanged(clearOldData: true);
        break;
      default:
        // Do nothing
        break;
    }
  }

  bool get isPrinterSelected => dataReady(_SelectedPrinterStreamKey);

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get hasServer => dataReady(_ServerStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get hasPrinter => dataReady(_PrinterStreamKey);
  bool get canUsePrinter => server.klippyState == KlipperState.ready;
  ConfigOutput? configForOutput(String name) {
    return printer.configFile.outputs[name];
  }

  onEditPin(OutputPin pin, ConfigOutput? configOutput) {
    int fractionToShow = (configOutput == null || !configOutput.pwm) ? 0 : 2;
    _dialogService
        .showCustomDialog(
            variant: DialogType.editForm,
            title: "Edit ${beautifyName(pin.name)} value!",
            mainButtonTitle: "Confirm",
            secondaryButtonTitle: "Cancel",
            data: EditFormDialogViewArguments(
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
            variant: DialogType.editForm,
            title: "Edit Part Cooling fan %",
            mainButtonTitle: "Confirm",
            secondaryButtonTitle: "Cancel",
            data: EditFormDialogViewArguments(
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
            variant: DialogType.editForm,
            title: "Edit ${beautifyName(namedFan.name)} %",
            mainButtonTitle: "Confirm",
            secondaryButtonTitle: "Cancel",
            data: EditFormDialogViewArguments(
                max: 100, current: namedFan.speed * 100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        _printerService?.genericFanFan(namedFan.name, v.toDouble() / 100);
      }
    });
  }

  String beautifyName(String name) {
    return name.replaceAll("_", " ").capitalize!;
  }

  String beautifyOutputName(NamedFan namedFan) {
    String name = namedFan.name;
    return name.replaceAll("_", " ").capitalize!;
  }

  onSelectedRetractChanged(int index) {
    selectedIndexRetractLength = index;
  }

  onRetractBtn() {
    var double = (retractLengths[selectedIndexRetractLength] * -1).toDouble();
    _printerService?.moveExtruder(double);
  }

  onDeRetractBtn() {
    var double = (retractLengths[selectedIndexRetractLength]).toDouble();
    _printerService?.moveExtruder(double);
  }

  onMacroPressed(int macroIndex) {
    _printerService?.gCodeMacro(printer.gcodeMacros[macroIndex]);
  }
}
