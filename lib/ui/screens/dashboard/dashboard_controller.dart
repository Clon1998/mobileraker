import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
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
  var selMachine = await ref.watch(selectedMachineProvider.future);
  if (selMachine == null){
    return;
  }



  var printer = ref.watchAsSubject(printerProvider(selMachine.uuid));
  var machineSettings = ref.watchAsSubject(selectedMachineSettingsProvider);
  var klippy = ref.watchAsSubject(klipperProvider(selMachine.uuid));
  var clientType = ref.watch(jrpcClientTypeProvider(selMachine.uuid));

  yield* Rx.combineLatest3(
      printer,
      klippy,
      machineSettings,
      (Printer a, KlipperInstance b, MachineSettings c) =>
          PrinterKlippySettingsMachineWrapper(
              printerData: a,
              klippyData: b,
              settings: c,
              machine: selMachine,
              clientType: clientType));
});

class PrinterKlippySettingsMachineWrapper {
  const PrinterKlippySettingsMachineWrapper(
      {required this.printerData,
      required this.klippyData,
      required this.settings,
      required this.machine,
      required this.clientType});

  final Printer printerData;
  final KlipperInstance klippyData;
  final MachineSettings settings;
  final Machine machine;
  final ClientType clientType;
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
