/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/machine_settings.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'dashboard_controller.g.dart';

final pageControllerProvider = Provider.autoDispose<PageController>((ref) {
  return PageController();
});

@riverpod
Stream<PrinterKlippySettingsMachineWrapper> machinePrinterKlippySettings(
  MachinePrinterKlippySettingsRef ref,
) async* {
  var selMachine = await ref.watch(selectedMachineProvider.future);
  if (selMachine == null) {
    return;
  }

  var klippy = ref.watchAsSubject(klipperProvider(selMachine.uuid));
  var printer = ref.watchAsSubject(printerProvider(selMachine.uuid));
  var machineSettings = ref.watchAsSubject(
    selectedMachineSettingsProvider,
    // THe skip is required because I want to use the cached value (So if the selectedMachineSettingsProvider goes into loading I still want to use the last valid value)
    // For the other two I want that this provider goes into the loading state, if I change them!
    skipLoadingOnReload: true,
  );
  var clientType = ref.watch(jrpcClientTypeProvider(selMachine.uuid));

  yield* Rx.combineLatest3(
    printer,
    klippy,
    machineSettings,
    (Printer a, KlipperInstance b, MachineSettings c) => PrinterKlippySettingsMachineWrapper(
      printerData: a,
      klippyData: b,
      settings: c,
      machine: selMachine,
      clientType: clientType,
    ),
  );
}

class PrinterKlippySettingsMachineWrapper {
  const PrinterKlippySettingsMachineWrapper({
    required this.printerData,
    required this.klippyData,
    required this.settings,
    required this.machine,
    required this.clientType,
  });

  final Printer printerData;
  final KlipperInstance klippyData;
  final MachineSettings settings;
  final Machine machine;
  final ClientType clientType;
}

final dashBoardViewControllerProvider = StateNotifierProvider.autoDispose<DashBoardViewController, int>((ref) {
  return DashBoardViewController(ref);
});

class DashBoardViewController extends StateNotifier<int> {
  DashBoardViewController(this.ref)
      : pageController = ref.watch(pageControllerProvider),
        super(0) {
    setupCalibrationDialogTriggers();
  }

  void setupCalibrationDialogTriggers() {
    // Manual Probe Dialog
    ref.listen(
      machinePrinterKlippySettingsProvider.selectAs((data) => data.printerData.manualProbe?.isActive),
      (previous, next) {
        var dialogService = ref.read(dialogServiceProvider);

        if (next.valueOrNull == true && !dialogService.isDialogOpen) {
          logger.i('Detected manualProbe... opening Dialog');
          dialogService.show(DialogRequest(
            barrierDismissible: false,
            type: DialogType.manualOffset,
          ));
        }
      },
      fireImmediately: true,
    );

    // Bed Screw Adjust
    ref.listen(
      machinePrinterKlippySettingsProvider.selectAs(
        (data) => data.printerData.bedScrew?.isActive,
      ),
      (previous, next) {
        var dialogService = ref.read(dialogServiceProvider);

        if (next.valueOrNull == true && !dialogService.isDialogOpen) {
          logger.i('Detected bedScrew... opening Dialog');
          ref.read(dialogServiceProvider).show(DialogRequest(
                barrierDismissible: false,
                type: DialogType.bedScrewAdjust,
              ));
        }
      },
      fireImmediately: true,
    );
  }

  final AutoDisposeRef ref;

  final PageController pageController;

  onBottomNavTapped(int value) {
    if (mounted) {
      pageController.animateToPage(
        value,
        duration: kThemeChangeDuration,
        curve: Curves.easeOutCubic,
      );
    }
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
