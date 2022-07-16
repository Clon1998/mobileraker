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
import 'package:stacked/stacked.dart';
import 'package:stringr/stringr.dart';

import 'dashboard_viewmodel.dart';

class DashboardView extends ViewModelBuilderWidget<DashboardViewModel> {
  const DashboardView({Key? key}) : super(key: key);

  @override
  Widget builder(
          BuildContext context, DashboardViewModel model, Widget? child) =>
      Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            child: Text(
              model.title,
              overflow: TextOverflow.fade,
            ),
            onHorizontalDragEnd: model.onHorizontalDragEnd,
          ),
          actions: <Widget>[
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: MachineStateIndicator(
                  model.isKlippyInstanceReady ? model.klippyInstance : null),
            ),
            IconButton(
              color: Theme.of(context).extension<CustomColors>()?.danger ??
                  Colors.red,
              icon: Icon(
                FlutterIcons.skull_outline_mco,
                size: 26,
              ),
              tooltip: tr('pages.dashboard.ems_btn'),
              onPressed: (model.canUseEms) ? model.onEmergencyPressed : null,
            ),
          ],
        ),
        body: ConnectionStateView(
          onConnected: model.hasPrinterDataError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FlutterIcons.sad_cry_faw5s, size: 99),
                      SizedBox(
                        height: 22,
                      ),
                      Text(
                        'Error while trying to fetch printer...\nPlease provide the error to the project owner\nvia GitHub!',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                          onPressed: model.showPrinterFetchingErrorDialog,
                          child: Text('Show Error'))
                    ],
                  ),
                )
              : (model.isPrinterDataReady)
                  ? PageView(
                      controller: model.pageController,
                      onPageChanged: model.onPageChanged,
                      children: [GeneralTab(), ControlTab()],
                    )
                  : Center(
                      child: Column(
                        key: UniqueKey(),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SpinKitFadingCube(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          SizedBox(
                            height: 30,
                          ),
                          FadingText(tr('pages.dashboard.fetching_printer')),
                          // Text("Fetching printer ...")
                        ],
                      ),
                    ),
        ),
        floatingActionButton: printingStateToFab(model),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        bottomNavigationBar: (model.isSelectedMachineReady &&
                model.isPrinterDataReady &&
                model.isKlippyInstanceReady)
            ? AnimatedBottomNavigationBar(
                // ToDo swap with Text
                icons: [
                  FlutterIcons.tachometer_faw,
                  // FlutterIcons.camera_control_mco,
                  FlutterIcons.settings_oct,
                ],
                activeColor: Theme.of(context)
                        .bottomNavigationBarTheme
                        .selectedItemColor ??
                    Theme.of(context).colorScheme.onPrimary,
                inactiveColor: Theme.of(context)
                    .bottomNavigationBarTheme
                    .unselectedItemColor,
                gapLocation: GapLocation.end,
                backgroundColor: Theme.of(context)
                        .bottomNavigationBarTheme
                        .backgroundColor ??
                    Theme.of(context).colorScheme.primary,
                notchSmoothness: NotchSmoothness.softEdge,
                activeIndex: model.currentIndex,
                onTap: model.onBottomNavTapped,
              )
            : null,
        drawer: NavigationDrawerWidget(curPath: Routes.dashboardView),
      );

  @override
  DashboardViewModel viewModelBuilder(BuildContext context) =>
      DashboardViewModel();

  Widget? printingStateToFab(DashboardViewModel model) {
    if (!model.isPrinterDataReady || !model.isKlippyInstanceReady) return null;

    if (model.klippyInstance.klippyState == KlipperState.error)
      return IdleFAB();

    switch (model.printerData.print.state) {
      case PrintState.printing:
        return FloatingActionButton(
          onPressed: model.onPausePrintPressed,
          child: Icon(Icons.pause),
        );
      case PrintState.paused:
        return PausedFAB();
      default:
        return IdleFAB();
    }
  }
}

class IdleFAB extends ViewModelWidget<DashboardViewModel> {
  const IdleFAB({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  Widget build(BuildContext context, DashboardViewModel model) {
    return FloatingActionButton(
        child: Icon(Icons.menu), onPressed: () => model.showNonPrintingMenu());
  }
}

class PausedFAB extends ViewModelWidget<DashboardViewModel> {
  const PausedFAB({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  Widget build(BuildContext context, DashboardViewModel model) {
    return SpeedDial(
      icon: FlutterIcons.options_vertical_sli,
      activeIcon: Icons.close,
      children: [
        SpeedDialChild(
          child: Icon(Icons.cleaning_services),
          backgroundColor: Colors.red,
          label: MaterialLocalizations.of(context)
              .cancelButtonLabel
              .toLowerCase()
              .titleCase(),
          onTap: model.onCancelPrintPressed,
        ),
        SpeedDialChild(
          child: Icon(Icons.play_arrow),
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
