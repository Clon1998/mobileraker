import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/components/bottomsheet/setup_bottom_sheet_ui.dart';
import 'package:mobileraker/ui/components/dialog/action_dialogs.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _PrinterStreamKey = 'printer';

class DashboardViewModel extends MultipleStreamViewModel {
  final _navigationService = locator<NavigationService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();
  final _settingService = locator<SettingService>();

  Machine? _machine;

  PrinterService? get _printerService => _machine?.printerService;

  KlippyService? get _klippyService => _machine?.klippyService;

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<Machine?>(_machineService.selectedMachine),
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

  setIndex(int value) {
    if (value < _currentIndex) {
      _reverse = true;
    } else {
      _reverse = false;
    }
    _currentIndex = value;
    notifyListeners();
  }

  bool isIndexSelected(int index) => _currentIndex == index;

  String get title =>
      '${machine?.name ?? 'Printer'} - ${tr('pages.dashboard.title')}';

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get isMachineAvailable => dataReady(_SelectedPrinterStreamKey);

  Machine? get machine => dataMap?[_SelectedPrinterStreamKey];

  bool get isServerAvailable => dataReady(_ServerStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  bool get isPrinterAvailable => dataReady(_PrinterStreamKey);

  bool get isKlippyConnected => _klippyService?.isKlippyConnected ?? false;

  @override
  onData(String key, data) {
    super.onData(key, data);
    switch (key) {
      case _SelectedPrinterStreamKey:
        Machine? nmachine = data;
        if (nmachine == _machine) break;
        _machine = nmachine;
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
      emergencyStopConfirmDialog(_dialogService).then((dialogResponse) {
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

  bool get canUseEms =>
      isServerAvailable && server.klippyState == KlipperState.ready;

  onHorizontalDragEnd(DragEndDetails endDetails) {
    double primaryVelocity = endDetails.primaryVelocity ?? 0;
    if (primaryVelocity < 0) {
      // Page forwards
      _machineService.selectPreviousMachine();
    } else if (primaryVelocity > 0) {
      // Page backwards
      _machineService.selectNextMachine();
    }
  }

  onPanUpdate(DragUpdateDetails updateDetails) {
    print(updateDetails);
  }

// onTitleSwipeDetection(SwipeDirection dir) {
//   switch (dir) {
//
//     case SwipeDirection.left:
//       _machineService.selectPreviousMachine();
//       break;
//     case SwipeDirection.right:
//       _machineService.selectNextMachine();
//
//       break;
//     default:
//   }
//
// }

}
