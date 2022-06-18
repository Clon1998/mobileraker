import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/common/mixins/klippy_multi_stream_view_model.dart';
import 'package:mobileraker/ui/common/mixins/mixable_multi_stream_view_model.dart';
import 'package:mobileraker/ui/common/mixins/printer_multi_stream_view_model.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_multi_stream_view_model.dart';
import 'package:mobileraker/ui/components/bottomsheet/setup_bottom_sheet_ui.dart';
import 'package:mobileraker/ui/components/dialog/action_dialogs.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class DashboardViewModel extends MixableMultiStreamViewModel
    with
        SelectedMachineMultiStreamViewModel,
        PrinterMultiStreamViewModel,
        KlippyMultiStreamViewModel {
  final _bottomSheetService = locator<BottomSheetService>();
  final _dialogService = locator<DialogService>();
  final _selectedMachineService = locator<SelectedMachineService>();
  final _settingService = locator<SettingService>();

  final PageController pageController = PageController();

  @override
  Map<String, StreamData> get streamsMap => super.streamsMap;

  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  bool _reverse = false;

  /// Indicates whether we're going forward or backward in terms of the index we're changing.
  /// This is very helpful for the page transition directions.
  bool get reverse => _reverse;

  onPageChanged(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  onBottomNavTapped(int value) {
    if (value < _currentIndex) {
      _reverse = true;
    } else {
      _reverse = false;
    }
    _currentIndex = value;
    pageController.animateToPage(_currentIndex,
        duration: kThemeChangeDuration, curve: Curves.ease);
    notifyListeners();
  }

  bool isIndexSelected(int index) => _currentIndex == index;

  String get title =>
      '${selectedMachine?.name ?? 'Printer'} - ${tr('pages.dashboard.title')}';

  bool get isKlippyConnected =>
      isKlippyInstanceReady && klippyService.isKlippyConnected;

  showNonPrintingMenu() async {
    await _bottomSheetService.showCustomSheet(
        variant: BottomSheetType.ManagementMenu);
  }

  onEmergencyPressed() {
    if (_settingService.readBool(emsKey))
      emergencyStopConfirmDialog(_dialogService).then((dialogResponse) {
        if (dialogResponse?.confirmed ?? false) klippyService.emergencyStop();
      });
    else
      klippyService.emergencyStop();
  }

  onPausePrintPressed() {
    printerService.pausePrint();
  }

  onCancelPrintPressed() {
    printerService.cancelPrint();
  }

  onResumePrintPressed() {
    printerService.resumePrint();
  }

  bool get canUseEms =>
      isKlippyInstanceReady && klippyInstance.klippyState == KlipperState.ready;

  onHorizontalDragEnd(DragEndDetails endDetails) {
    double primaryVelocity = endDetails.primaryVelocity ?? 0;
    if (primaryVelocity < 0) {
      // Page forwards
      _selectedMachineService.selectPreviousMachine();
    } else if (primaryVelocity > 0) {
      // Page backwards
      _selectedMachineService.selectNextMachine();
    }
  }
}
