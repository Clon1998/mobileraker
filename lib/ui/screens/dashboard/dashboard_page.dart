/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:badges/badges.dart' as badges;
import 'package:common/data/dto/job_queue/job_queue_status.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/connection/printer_provider_guard.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/ems_button.dart';
import 'package:mobileraker/ui/components/filament_sensor_watcher.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/components/printer_calibration_watcher.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/control_tab.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/general_tab.dart';
import 'package:mobileraker_pro/service/moonraker/job_queue_service.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:rate_my_app/rate_my_app.dart';

import '../../components/connection/machine_connection_guard.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RateMyAppBuilder(
      rateMyApp: RateMyApp(minDays: 2, minLaunches: 5, remindDays: 7),
      onInitialized: (context, rateMyApp) {
        if (rateMyApp.shouldOpenDialog) {
          rateMyApp.showRateDialog(
            context,
            title: tr('dialogs.rate_my_app.title'),
            message: tr('dialogs.rate_my_app.message'),
          );
        }
      },
      builder: (context) => const _DashboardView(),
    );
  }
}

class _DashboardView extends HookConsumerWidget {
  const _DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pageController = usePageController(keys: []);
    ref.listen(selectedMachineProvider, (previous, next) {
      if (previous == null) return;
      if (previous.valueOrNull?.uuid != next.valueOrNull?.uuid) {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          if (pageController.positions.length == 1) {
            pageController.jumpToPage(0);
          }
        });
      }
    });

    var activeMachine = ref.watch(selectedMachineProvider).valueOrNull;

    return Scaffold(
      appBar: SwitchPrinterAppBar(
        title: tr('pages.dashboard.title'),
        actions: <Widget>[
          MachineStateIndicator(activeMachine),
          const EmergencyStopBtn(),
        ],
      ),
      body: MachineConnectionGuard(
        onConnected: (ctx, machineUUID) => PrinterProviderGuard(
          machineUUID: machineUUID,
          child: _DashboardBody(
            controller: pageController,
            machineUUID: machineUUID,
          ),
        ),
      ),
      floatingActionButton: const _FloatingActionBtn(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: _BottomNavigationBar(pageController: pageController),
      drawer: const NavigationDrawerWidget(),
    );
  }
}

class _FloatingActionBtn extends ConsumerWidget {
  const _FloatingActionBtn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<KlipperState> klippyState = ref.watch(klipperSelectedProvider.selectAs((data) => data.klippyState));
    AsyncValue<PrintState> printState = ref.watch(printerSelectedProvider.selectAs((data) => data.print.state));

    AsyncValue<JobQueueStatus> jobQueueState = ref.watch(jobQueueSelectedProvider);

    if (!klippyState.hasValue ||
        !printState.hasValue ||
        klippyState.isLoading ||
        printState.isLoading ||
        klippyState.hasError ||
        printState.hasError) {
      return const SizedBox.shrink();
    }

    if (klippyState.value == KlipperState.error ||
        !{PrintState.printing, PrintState.paused}.contains(printState.value)) {
      return const _IdleFAB();
    }

    ThemeData themeData = Theme.of(context);
    return SpeedDial(
      icon: FlutterIcons.options_vertical_sli,
      activeIcon: Icons.close,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.cleaning_services),
          backgroundColor: themeData.colorScheme.error,
          foregroundColor: themeData.colorScheme.onError,
          label: tr('general.cancel'),
          onTap: ref.watch(printerServiceSelectedProvider).cancelPrint,
        ),
        if (printState.value == PrintState.paused)
          SpeedDialChild(
            child: Icon(
              Icons.play_arrow,
              color: themeData.colorScheme.onPrimaryContainer,
            ),
            backgroundColor: themeData.colorScheme.primaryContainer,
            label: tr('general.resume'),
            onTap: ref.watch(printerServiceSelectedProvider).resumePrint,
          ),
        if (printState.value == PrintState.printing)
          SpeedDialChild(
            child: Icon(
              Icons.pause,
              color: themeData.colorScheme.onPrimaryContainer,
            ),
            backgroundColor: themeData.colorScheme.primaryContainer,
            label: tr('general.pause'),
            onTap: ref.watch(printerServiceSelectedProvider).pausePrint,
          ),
        if (jobQueueState.valueOrNull?.queuedJobs.isNotEmpty ?? false)
          SpeedDialChild(
            child: badges.Badge(
              badgeStyle: badges.BadgeStyle(
                badgeColor: themeData.colorScheme.onSecondary,
              ),
              badgeAnimation: const badges.BadgeAnimation.rotation(),
              position: badges.BadgePosition.bottomEnd(end: -7, bottom: -11),
              badgeContent: Text(
                '${jobQueueState.valueOrNull?.queuedJobs.length ?? 0}',
                style: TextStyle(color: themeData.colorScheme.secondary),
              ),
              child: const Icon(Icons.content_paste),
            ),
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
            label: tr('dialogs.supporter_perks.job_queue_perk.title'),
            onTap: () => ref
                .read(bottomSheetServiceProvider)
                .show(BottomSheetConfig(type: ProSheetType.jobQueueMenu, isScrollControlled: true)),
          ),
      ],
      spacing: 5,
      overlayOpacity: 0,
    );
  }
}

class _BottomNavigationBar extends HookConsumerWidget {
  const _BottomNavigationBar({super.key, required this.pageController});

  final PageController pageController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var colorScheme = themeData.colorScheme;
    var lastIndex = useRef(0);

    int activeIndex = useListenableSelector(pageController, () {
      if (pageController.positions.length == 1) {
        lastIndex.value = pageController.page?.round() ?? 0;
      }
      return lastIndex.value;
    });

    return AnimatedBottomNavigationBar(
      icons: const [FlutterIcons.tachometer_faw, FlutterIcons.settings_oct],
      activeColor: themeData.bottomNavigationBarTheme.selectedItemColor ?? colorScheme.onPrimary,
      inactiveColor: themeData.bottomNavigationBarTheme.unselectedItemColor,
      gapLocation: GapLocation.end,
      backgroundColor: themeData.bottomNavigationBarTheme.backgroundColor ?? colorScheme.primary,
      notchSmoothness: NotchSmoothness.softEdge,
      activeIndex: activeIndex,
      splashSpeedInMilliseconds: kThemeAnimationDuration.inMilliseconds,
      onTap: (index) {
        if (pageController.hasClients) {
          pageController.animateToPage(index, duration: kThemeChangeDuration, curve: Curves.easeOutCubic);
        }
      },
    );
  }
}

class _DashboardBody extends HookConsumerWidget {
  const _DashboardBody({super.key, required this.controller, required this.machineUUID});

  final PageController controller;

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PrinterCalibrationWatcher(
      machineUUID: machineUUID,
      child: FilamentSensorWatcher(
        machineUUID: machineUUID,
        child: PageView(
          key: const PageStorageKey<String>('dashboardPages'),
          controller: controller,
          children: [GeneralTab(machineUUID), ControlTab(machineUUID)],
        ),
      ),
    );
  }
}

class _IdleFAB extends ConsumerWidget {
  const _IdleFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FloatingActionButton(
        onPressed: () {
          ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: SheetType.nonPrintingMenu));
        },

        // onPressed: mdodel.showNonPrintingMenu,
        child: const Icon(Icons.menu),
      );
}
