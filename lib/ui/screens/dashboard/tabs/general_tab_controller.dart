/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';

// part 'general_tab_controller.g.dart';

final generalTabViewControllerProvider =
    StateNotifierProvider.autoDispose<GeneralTabViewController, AsyncValue<PrinterKlippySettingsMachineWrapper>>(
  name: 'generalTabViewControllerProvider',
  (ref) => GeneralTabViewController(ref),
);

class GeneralTabViewController extends StateNotifier<AsyncValue<PrinterKlippySettingsMachineWrapper>> {
  GeneralTabViewController(this.ref) : super(ref.read(machinePrinterKlippySettingsProvider)) {
    ref.listen<AsyncValue<PrinterKlippySettingsMachineWrapper>>(
      machinePrinterKlippySettingsProvider,
      (previous, next) {
        // if (next.isRefreshing) state = const AsyncValue.loading();
        state = next;
      },
    );
  }

  final AutoDisposeRef ref;

  onRestartKlipperPressed() {
    ref.read(klipperServiceSelectedProvider).restartKlipper();
  }

  onRestartMCUPressed() {
    ref.read(klipperServiceSelectedProvider).restartMCUs();
  }

  onExcludeObjectPressed() {
    ref.read(dialogServiceProvider).show(DialogRequest(type: DialogType.excludeObject));
  }

  onResetPrintTap() {
    ref.watch(printerServiceSelectedProvider).resetPrintStat();
  }

  onReprintTap() {
    ref.watch(printerServiceSelectedProvider).reprintCurrentFile();
  }

  onClearM117() {
    ref.read(printerServiceSelectedProvider).m117();
  }
}
