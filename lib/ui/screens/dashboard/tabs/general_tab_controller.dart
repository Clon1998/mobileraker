/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:hooks_riverpod/hooks_riverpod.dart';
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


}
