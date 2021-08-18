import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/dto/server/Klipper.dart';
import 'package:mobileraker/enums/BottomSheetType.dart';
import 'package:mobileraker/service/KlippyService.dart';
import 'package:mobileraker/service/PrinterService.dart';
import 'package:mobileraker/service/MachineService.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';

class OverViewModel extends MultipleStreamViewModel {
  final _navigationService = locator<NavigationService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _machineService = locator<MachineService>();


  PrinterSetting? _printerSetting;

  PrinterService? _printerService;
  KlippyService? _klippyService;

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey: StreamData<PrinterSetting?>(
            _machineService.selectedPrinter),
        if (_printerSetting?.printerService != null) ...{
          _PrinterStreamKey: StreamData<Printer>(_printerService!.printerStream)
        },
        if (_printerSetting?.klippyService != null) ...{
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream)
        }
        // _ServerStreamKey:
        // StreamData<KlipperInstance>(),
        // _PrinterStreamKey: StreamData<Printer>(),
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

  String get title => '${selectedPrinter?.name ?? 'Printer'} - Dashboard';

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get isPrinterSelected => dataReady(_SelectedPrinterStreamKey);

  PrinterSetting? get selectedPrinter => dataMap?[_SelectedPrinterStreamKey];

  bool get hasServer => dataReady(_ServerStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get hasPrinter => dataReady(_PrinterStreamKey);

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


  showNonPrintingMenu() async {
    await _bottomSheetService.showCustomSheet(
        variant: BottomSheetType.ManagementMenu);
  }

  onEmergencyPressed() {
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

  navigateToSettings() {
    //Navigate to other View:::
    _navigationService.navigateTo(Routes.settingView);
  }


  fffff() {
    // _navigationService.navigateTo(Routes.testView);
    // print("asdasd");
  }
}
