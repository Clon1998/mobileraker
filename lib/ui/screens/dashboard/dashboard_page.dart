/*
 * Copyright (c) 2023. Patrick Schmidt.
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
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/ems_button.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/components/selected_printer_app_bar.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/control_tab.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/general_tab.dart';
import 'package:mobileraker_pro/service/moonraker/job_queue_service.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:rate_my_app/rate_my_app.dart';

import 'dashboard_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RateMyAppBuilder(
      rateMyApp: RateMyApp(
        minDays: 2,
        minLaunches: 5,
        remindDays: 7,
      ),
      onInitialized: (context, rateMyApp) {
        if (rateMyApp.shouldOpenDialog) {
          rateMyApp.showRateDialog(context,
              title: tr('dialogs.rate_my_app.title'), message: tr('dialogs.rate_my_app.message'));
        }
      },
      builder: (context) => const _DashboardView(),
    );
  }
}

class _DashboardView extends ConsumerWidget {
  const _DashboardView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: SwitchPrinterAppBar(
        title: tr('pages.dashboard.title'),
        actions: <Widget>[
          MachineStateIndicator(ref.watch(selectedMachineProvider).valueOrNull),
          const EmergencyStopBtn(),
        ],
      ),
      body: const ConnectionStateView(onConnected: _DashboardBody()),
      floatingActionButton: const _FloatingActionBtn(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: const _BottomNavigationBar(),
      drawer: const NavigationDrawerWidget(),
    );
  }
}

class _FloatingActionBtn extends ConsumerWidget {
  const _FloatingActionBtn({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<KlipperState> klippyState = ref.watch(klipperSelectedProvider.selectAs((data) => data.klippyState));
    AsyncValue<PrintState> printState = ref.watch(printerSelectedProvider.selectAs((data) => data.print.state));

    AsyncValue<JobQueueStatus> jobQueueState = ref.watch(jobQueueSelectedProvider);

    if (!klippyState.hasValue || !printState.hasValue || klippyState.isLoading || printState.isLoading) {
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
              badgeContent: Text('${jobQueueState.valueOrNull?.queuedJobs.length ?? 0}',
                  style: TextStyle(color: themeData.colorScheme.secondary)),
              child: const Icon(Icons.content_paste),
            ),
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
            label: tr('dialogs.supporter_perks.job_queue_perk.title'),
            onTap: () => ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: SheetType.jobQueueMenu)),
          ),
      ],
      spacing: 5,
      overlayOpacity: 0,
    );
  }
}

class _BottomNavigationBar extends ConsumerWidget {
  const _BottomNavigationBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var colorScheme = themeData.colorScheme;

    if (ref.watch(machinePrinterKlippySettingsProvider.selectAs((data) => true)).valueOrNull != true) {
      return const SizedBox.shrink();
    }

    // AsyncValue<KlipperState> klippyState =
    //     ref.watch(klipperSelectedProvider.selectAs((data) => data.klippyState));
    // AsyncValue<PrintState> printState =
    //     ref.watch(printerSelectedProvider.selectAs((data) => data.print.state));
    //
    // if (!klippyState.hasValue || !printState.hasValue) {
    //   return const SizedBox.shrink();
    // }

    return AnimatedBottomNavigationBar(
      icons: const [
        FlutterIcons.tachometer_faw,
        FlutterIcons.settings_oct,
      ],
      activeColor: themeData.bottomNavigationBarTheme.selectedItemColor ?? colorScheme.onPrimary,
      inactiveColor: themeData.bottomNavigationBarTheme.unselectedItemColor,
      gapLocation: GapLocation.end,
      backgroundColor: themeData.bottomNavigationBarTheme.backgroundColor ?? colorScheme.primary,
      notchSmoothness: NotchSmoothness.softEdge,
      activeIndex: ref.watch(dashBoardViewControllerProvider),
      onTap: ref.watch(dashBoardViewControllerProvider.notifier).onBottomNavTapped,
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        // We use selectAs null since we want to prevent rebuilding this widget to often!
        .watch(machinePrinterKlippySettingsProvider.selectAs((data) => true))
        .when<Widget>(
          data: (d) => PageView(
            key: const PageStorageKey<String>('dashboardPages'),
            controller: ref.watch(pageControllerProvider),
            onPageChanged: ref.watch(dashBoardViewControllerProvider.notifier).onPageChanged,
            children: const [GeneralTab(), ControlTab()],
            // children: [const GeneralTab(), const ControlTab()],
          ),
          error: (e, s) {
            //TODO Error catching wont work..... does not work .....
            logger.e('Error in Dash', e, s);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(FlutterIcons.sad_cry_faw5s, size: 99),
                  const SizedBox(
                    height: 22,
                  ),
                  const Text(
                    'Error while trying to fetch printer...\nPlease provide the error to the project owner\nvia GitHub!',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                      onPressed: () => ref.read(dialogServiceProvider).show(DialogRequest(
                          type: CommonDialogs.stacktrace,
                          title: e.runtimeType.toString(),
                          body: 'Exception:\n $e\n\n$s')),
                      child: const Text('Show Error'))
                ],
              ),
            );
          },
          loading: () => Center(
              child: Column(
            key: UniqueKey(),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingCube(
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(
                height: 30,
              ),
              FadingText(tr('pages.dashboard.fetching_printer')),
              // Text("Fetching printer ...")
            ],
          )),
        );
  }
}

class _IdleFAB extends ConsumerWidget {
  const _IdleFAB({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) => FloatingActionButton(
      onPressed: () async {
        ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: SheetType.nonPrintingMenu));
      },

      // onPressed: mdodel.showNonPrintingMenu,
      child: const Icon(Icons.menu));
}
