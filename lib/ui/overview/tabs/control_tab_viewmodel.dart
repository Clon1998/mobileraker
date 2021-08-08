
import 'package:mobileraker/app/AppSetup.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/dto/server/Klipper.dart';
import 'package:mobileraker/service/KlippyService.dart';
import 'package:mobileraker/service/PrinterService.dart';
import 'package:mobileraker/service/SelectedMachineService.dart';
import 'package:mobileraker/ui/dialog/editForm/editForm_view.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';

class ControlTabViewModel extends MultipleStreamViewModel {
  final _dialogService = locator<DialogService>();
  final _selectedMachineService = locator<SelectedMachineService>();

  List<int> retractLengths = [1, 10, 25, 50];

  int selectedIndexRetractLength = 0;


  PrinterSetting? _printerSetting;
  PrinterService? _printerService;
  KlippyService? _klippyService;

  //ToDO: Maybe to pass these down from the overview viewmodel..
  @override
  Map<String, StreamData> get streamsMap => {
    _SelectedPrinterStreamKey: StreamData<PrinterSetting?>(
        _selectedMachineService.selectedPrinter),
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

  onEditPin(OutputPin pin) {
    _dialogService
        .showCustomDialog(
        variant: DialogType.editForm,
        title: "Edit ${pin.name} %",
        mainButtonTitle: "Confirm",
        secondaryButtonTitle: "Cancel",
        data: EditFormDialogViewArguments(max: 100, current: pin.value*100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        _printerService?.outputPin(pin.name,v.toDouble()/10);
      }
    });
  }

  onEditFan() {
    _dialogService
        .showCustomDialog(
        variant: DialogType.editForm,
        title: "Edit Part Cooling fan %",
        mainButtonTitle: "Confirm",
        secondaryButtonTitle: "Cancel",
        data: EditFormDialogViewArguments(max: 100,current: printer.printFan.speed*100.round()))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        _printerService?.partCoolingFan(v.toDouble()/100);
      }
    });
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
