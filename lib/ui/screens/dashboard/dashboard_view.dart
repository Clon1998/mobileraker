import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/control_tab.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/general_tab.dart';
import 'package:mobileraker/ui/theme/theme_pack.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:stringr/stringr.dart';

import 'dashboard_viewmodel.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RateMyAppBuilder(
      rateMyApp: RateMyApp(
        minDays: 2,
        minLaunches: 1,
        remindDays: 7,
      ),
      onInitialized: (context, rateMyApp) {
        if (rateMyApp.shouldOpenDialog) {
          rateMyApp.showRateDialog(context,
              title: tr('dialogs.rate_my_app.title'),
              message: tr('dialogs.rate_my_app.message'));
        }
      },
      builder: (context) => const _DashboardView(),
    );
  }
}

class _DashboardView extends ConsumerWidget {
  const _DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(selectedMachineProvider).valueOrFullNull;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onHorizontalDragEnd: ref
              .watch(dashBoardViewControllerProvider.notifier)
              .onHorizontalDragEnd,
          child: Text(
            '${machine?.name ?? 'Printer'} - ${tr('pages.dashboard.title')}',
            overflow: TextOverflow.fade,
          ),
        ),
        actions: const <Widget>[
          MachineStateIndicator(),
          _EmergencyStopBtn(),
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

class _EmergencyStopBtn extends ConsumerWidget {
  const _EmergencyStopBtn({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    KlipperState klippyState = ref.watch(klipperSelectedProvider.select(
        (value) =>
            value.valueOrFullNull?.klippyState ?? KlipperState.disconnected));

    return IconButton(
      color: Theme.of(context).extension<CustomColors>()?.danger ?? Colors.red,
      icon: const Icon(
        FlutterIcons.skull_outline_mco,
        size: 26,
      ),
      tooltip: tr('pages.dashboard.ems_btn'),
      onPressed: klippyState == KlipperState.ready
          ? ref.read(klipperServiceSelectedProvider).emergencyStop
          : null,
    );
  }
}

class _FloatingActionBtn extends ConsumerWidget {
  const _FloatingActionBtn({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<KlipperState> klippyState =
        ref.watch(klipperSelectedProvider.selectAs((data) => data.klippyState));
    AsyncValue<PrintState> printState =
        ref.watch(printerSelectedProvider.selectAs((data) => data.print.state));

    if (!klippyState.hasValue || !printState.hasValue) {
      return const SizedBox.shrink();
    }

    if (klippyState.value! == KlipperState.error) return const _IdleFAB();

    switch (printState.value!) {
      case PrintState.printing:
        return FloatingActionButton(
          onPressed: ref.read(printerServiceSelectedProvider).pausePrint(),
          child: const Icon(Icons.pause),
        );
      case PrintState.paused:
        return const _PausedFAB();
      default:
        return const _IdleFAB();
    }
  }
}

class _BottomNavigationBar extends ConsumerWidget {
  const _BottomNavigationBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var colorScheme = themeData.colorScheme;

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
      activeColor: themeData.bottomNavigationBarTheme.selectedItemColor ??
          colorScheme.onPrimary,
      inactiveColor: themeData.bottomNavigationBarTheme.unselectedItemColor,
      gapLocation: GapLocation.end,
      backgroundColor: themeData.bottomNavigationBarTheme.backgroundColor ??
          colorScheme.primary,
      notchSmoothness: NotchSmoothness.softEdge,
      activeIndex: ref.watch(dashBoardViewControllerProvider),
      onTap:
          ref.watch(dashBoardViewControllerProvider.notifier).onBottomNavTapped,
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.wtf('_BUILDING DASHBOARD BODY ');
    return ref
        // We use selectAs null since we want to prevent rebuilding this widget to often!
        .watch(printerSelectedProvider.selectAs((data) => true))
        .when<Widget>(
          data: (d) => ProviderScope(
            disposeDelay: const Duration(minutes: 10),
            cacheTime: const Duration(minutes: 10),
            child: PageView(
              key: const PageStorageKey<String>('dashboardPages'),
              controller: ref
                  .watch(pageControllerProvider),
              onPageChanged: ref
                  .watch(dashBoardViewControllerProvider.notifier)
                  .onPageChanged,
              children: const [GeneralTab(), ControlTab()],
              // children: [const GeneralTab(), const ControlTab()],
            ),
          ),
          error: (e, s) {
            //TODO Error catching wont work..... does not work .....

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(FlutterIcons.sad_cry_faw5s, size: 99),
                  SizedBox(
                    height: 22,
                  ),
                  Text(
                    'Error while trying to fetch printer...\nPlease provide the error to the project owner\nvia GitHub!',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                      // onPressed: model.showPrinterFetchingErrorDialog,
                      onPressed: null,
                      child: Text('Show Error'))
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
        ref
            .read(bottomSheetServiceProvider)
            .show(BottomSheetConfig(type: SheetType.nonPrintingMenu));

        // ref
        //     .read(dialogServiceProvider)
        //     .show(DialogConfig(title: 'My FABs'));
        // ref.read(snackBarServiceProvider).showSnackBar(SnackBarConfig(title: 'Idlle FABs'));
      },
      // onPressed: mdodel.showNonPrintingMenu,
      child: const Icon(Icons.menu));
}

class _PausedFAB extends ConsumerWidget {
  const _PausedFAB({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SpeedDial(
      icon: FlutterIcons.options_vertical_sli,
      activeIcon: Icons.close,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.cleaning_services),
          backgroundColor: Colors.red,
          label: MaterialLocalizations.of(context)
              .cancelButtonLabel
              .toLowerCase()
              .titleCase(),
          // onTap: model.onCancelPrintPressed,
          onTap: null,
        ),
        SpeedDialChild(
          child: const Icon(Icons.play_arrow),
          backgroundColor: Colors.blue,
          label: tr('general.resume'),
          // onTap: model.onResumePrintPressed,
          onTap: null,
        ),
      ],
      spacing: 5,
      overlayOpacity: 0,
    );
  }
}
