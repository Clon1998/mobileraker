import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/ref_extension.dart';
import 'package:rxdart/rxdart.dart';

final pageControllerProvider = Provider.autoDispose<PageController>((ref) {
  return PageController();
});

final machinePrinterKlippySettingsProvider =
    StreamProvider.autoDispose<PrinterKlippySettingsMachineWrapper>(
        name: 'machinePrinterKlippySettingsProvider', (ref) async* {
  var selMachine = ref.watchAsSubject(selectedMachineProvider).whereNotNull();
  var printer = ref.watchAsSubject(printerSelectedProvider);
  var machineSettings = ref.watchAsSubject(selectedMachineSettingsProvider);
  var klippy = ref.watchAsSubject(klipperSelectedProvider);

  yield* Rx.combineLatest4(
      printer,
      klippy,
      machineSettings,
      selMachine,
      (Printer a, KlipperInstance b, MachineSettings c, Machine d) =>
          PrinterKlippySettingsMachineWrapper(
              printerData: a, klippyData: b, settings: c, machine: d));
});

class PrinterKlippySettingsMachineWrapper {
  const PrinterKlippySettingsMachineWrapper(
      {required this.printerData,
      required this.klippyData,
      required this.settings,
      required this.machine});

  final Printer printerData;
  final KlipperInstance klippyData;
  final MachineSettings settings;
  final Machine machine;
}

final dashBoardViewControllerProvider =
    StateNotifierProvider.autoDispose<DashBoardViewController, int>((ref) {
  return DashBoardViewController(ref);
});

class DashBoardViewController extends StateNotifier<int> {
  DashBoardViewController(this.ref)
      : pageController = ref.watch(pageControllerProvider),
        super(0);

  final AutoDisposeRef ref;

  final PageController pageController;

  onBottomNavTapped(int value) {
    pageController.animateToPage(value,
        duration: kThemeChangeDuration, curve: Curves.easeOutCubic);
  }

  onPageChanged(int index) {
    state = index;
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
  }
}
