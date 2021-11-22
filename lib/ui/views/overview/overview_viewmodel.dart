import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/enums/bottom_sheet_type.dart';
import 'package:mobileraker/service/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/views/setting/setting_viewmodel.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';

class OverViewModel extends MultipleStreamViewModel {
  final _navigationService = locator<NavigationService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();
  final _settingService = locator<SettingService>();

  PrinterSetting? _printerSetting;

  PrinterService? get _printerService => _printerSetting?.printerService;

  KlippyService? get _klippyService => _printerSetting?.klippyService;

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<PrinterSetting?>(_machineService.selectedMachine),
        if (_printerService != null)
          _PrinterStreamKey:
              StreamData<Printer>(_printerService!.printerStream),

        if (_klippyService != null)
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream)
      };

  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  bool _reverse = false;

  /// Indicates whether we're going forward or backward in terms of the index we're changing.
  /// This is very helpful for the page transition directions.
  bool get reverse => _reverse;

  void setIndex(int value) {
    if (value < _currentIndex) {
      _reverse = true;
    } else {
      _reverse = false;
    }
    _currentIndex = value;
    notifyListeners();
  }

  bool isIndexSelected(int index) => _currentIndex == index;

  String get title => '${machine?.name ?? 'Printer'} - Dashboard';

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get isMachineAvailable => dataReady(_SelectedPrinterStreamKey);

  PrinterSetting? get machine => dataMap?[_SelectedPrinterStreamKey];

  bool get isServerAvailable => dataReady(_ServerStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get isPrinterAvailable => dataReady(_PrinterStreamKey);

  bool get isKlippyConnected => _klippyService?.isKlippyConnected ?? false;

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case _SelectedPrinterStreamKey:
        PrinterSetting? nPrinterSetting = data;
        if (nPrinterSetting == _printerSetting) break;
        _printerSetting = nPrinterSetting;
        notifySourceChanged(clearOldData: true);
        break;

      default:
        // Do nothing
        break;
    }
  }

  showNonPrintingMenu() async {
    await _bottomSheetService.showCustomSheet(
        variant: BottomSheetType.ManagementMenu);
  }

  onEmergencyPressed() {
    if (_settingService.readBool(emsKey))
      _dialogService
          .showConfirmationDialog(
        title: "Emergency Stop - Confirmation",
        description: "Are you sure?",
        confirmationTitle: "STOP!",
      )
          .then((dialogResponse) {
        if (dialogResponse?.confirmed ?? false) _klippyService?.emergencyStop();
      });
    else
      _klippyService?.emergencyStop();
  }

  onPausePrintPressed() {
    _printerService?.pausePrint();
  }

  onCancelPrintPressed() {
    _printerService?.cancelPrint();
  }

  onResumePrintPressed() {
    _printerService?.resumePrint();
  }
}
