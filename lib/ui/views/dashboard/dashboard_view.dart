import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/themes/theme_pack.dart';
import 'package:mobileraker/ui/views/dashboard/tabs/control_tab.dart';
import 'package:mobileraker/ui/views/dashboard/tabs/general_tab.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:stacked/stacked.dart';
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
        if (rateMyApp.shouldOpenDialog)
          rateMyApp.showRateDialog(context,
              title: tr('dialogs.rate_my_app.title'),
              message: tr('dialogs.rate_my_app.message'));
      },
      builder: (context) => const _DashboardView(),
    );
  }
}

class _DashboardView extends ViewModelBuilderWidget<DashboardViewModel> {
  const _DashboardView({Key? key}) : super(key: key);

  @override
  bool get reactive => false;

  @override
  Widget builder(
      BuildContext context, DashboardViewModel model, Widget? child) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          child: Text(
            model.title,
            overflow: TextOverflow.fade,
          ),
          onHorizontalDragEnd: model.onHorizontalDragEnd,
        ),
        actions: <Widget>[
          const _MachineIndicator(),
          const _EmergencyStopBtn(),
        ],
      ),
      body: const _DashboardBody(),
      floatingActionButton: const _FloatingActionBtn(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: const _BottomNavigationBar(),
      drawer: const NavigationDrawerWidget(curPath: Routes.dashboardView),
    );
  }

  @override
  DashboardViewModel viewModelBuilder(BuildContext context) =>
      DashboardViewModel();
}

class _EmergencyStopBtn extends ViewModelWidget<DashboardViewModel> {
  const _EmergencyStopBtn({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, DashboardViewModel model) => IconButton(
        color:
            Theme.of(context).extension<CustomColors>()?.danger ?? Colors.red,
        icon: const Icon(
          FlutterIcons.skull_outline_mco,
          size: 26,
        ),
        tooltip: tr('pages.dashboard.ems_btn'),
        onPressed: (model.canUseEms) ? model.onEmergencyPressed : null,
      );
}

class _MachineIndicator extends ViewModelWidget<DashboardViewModel> {
  const _MachineIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, DashboardViewModel model) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: MachineStateIndicator(
            model.isKlippyInstanceReady ? model.klippyInstance : null),
      );
}

class _FloatingActionBtn extends ViewModelWidget<DashboardViewModel> {
  const _FloatingActionBtn({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, DashboardViewModel model) {
    if (!model.isPrinterDataReady ||
        !model.isKlippyInstanceReady ||
        !model.isSelectedMachineReady) return const SizedBox.shrink();

    if (model.klippyInstance.klippyState == KlipperState.error)
      return _IdleFAB();

    switch (model.printerData.print.state) {
      case PrintState.printing:
        return FloatingActionButton(
          onPressed: model.onPausePrintPressed,
          child: const Icon(Icons.pause),
        );
      case PrintState.paused:
        return _PausedFAB();
      default:
        return _IdleFAB();
    }
  }
}

class _BottomNavigationBar extends ViewModelWidget<DashboardViewModel> {
  const _BottomNavigationBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, DashboardViewModel model) {
    var themeData = Theme.of(context);
    var colorScheme = themeData.colorScheme;
    if (model.isSelectedMachineReady &&
        model.isPrinterDataReady &&
        model.isKlippyInstanceReady)
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
        activeIndex: model.currentIndex,
        onTap: model.onBottomNavTapped,
      );

    return const SizedBox.shrink();
  }
}

class _DashboardBody extends ViewModelWidget<DashboardViewModel> {
  const _DashboardBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, DashboardViewModel model) =>
      ConnectionStateView(
        onConnected: model.hasPrinterDataError
            ? Center(
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
                        onPressed: model.showPrinterFetchingErrorDialog,
                        child: const Text('Show Error'))
                  ],
                ),
              )
            : (model.isPrinterDataReady)
                ? PageView(
                    controller: model.pageController,
                    onPageChanged: model.onPageChanged,
                    children: [const GeneralTab(), const ControlTab()],
                  )
                : Center(
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
                    ),
                  ),
      );
}

class _IdleFAB extends ViewModelWidget<DashboardViewModel> {
  const _IdleFAB({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  bool get reactive => false;

  @override
  Widget build(BuildContext context, DashboardViewModel model) =>
      FloatingActionButton(
          child: const Icon(Icons.menu), onPressed: model.showNonPrintingMenu);
}

class _PausedFAB extends ViewModelWidget<DashboardViewModel> {
  const _PausedFAB({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  bool get reactive => false;

  @override
  Widget build(BuildContext context, DashboardViewModel model) {
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
          onTap: model.onCancelPrintPressed,
        ),
        SpeedDialChild(
          child: const Icon(Icons.play_arrow),
          backgroundColor: Colors.blue,
          label: tr('general.resume'),
          onTap: model.onResumePrintPressed,
        ),
      ],
      spacing: 5,
      overlayOpacity: 0,
    );
  }
}
