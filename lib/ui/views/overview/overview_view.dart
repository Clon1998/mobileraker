import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/views/overview/tabs/control_tab.dart';
import 'package:mobileraker/ui/views/overview/tabs/general_tab.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

import 'overview_viewmodel.dart';

class OverView extends StatelessWidget {
  const OverView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<OverViewModel>.reactive(
      builder: (context, model, child) => Scaffold(
        appBar: AppBar(
          title: Text(
            model.title,
            overflow: TextOverflow.fade,
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.radio_button_on,
                  size: 10,
                  color: stateToColor(model.hasServer
                      ? model.server.klippyState
                      : KlipperState.error)),
              tooltip: model.hasServer
                  ? 'Server State is ${toName(model.server.klippyState)} and Moonraker is ${model.server.klippyConnected ? 'connected' : 'disconnected'} to Klipper'
                  : 'Server is not connected',
              onPressed: () => null,
            ),
            IconButton(
              color: Colors.red,
              icon: Icon(
                Icons.dangerous_outlined,
                size: 30,
              ),
              tooltip: 'Emergency-Stop',
              onPressed: (model.hasServer) ? model.onEmergencyPressed : null,
            ),
          ],
        ),
        body: ConnectionStateView(
          pChild: (model.hasPrinter)
              ? PageTransitionSwitcher(
                  duration: const Duration(milliseconds: 300),
                  reverse: model.reverse,
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                  ) {
                    return SharedAxisTransition(
                      child: child,
                      animation: animation,
                      secondaryAnimation: secondaryAnimation,
                      transitionType: SharedAxisTransitionType.horizontal,
                    );
                  },
                  child: getViewForIndex(model.currentIndex),
                )
              : Center(
                  child: Column(
                    key: UniqueKey(),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitFadingCube(
                        color: Colors.orange,
                      ),
                      SizedBox(
                        height: 30,
                      ),
                      FadingText("Fetching printer..."),
                      // Text("Fetching printer ...")
                    ],
                  ),
                ),
        ),
        floatingActionButton: printingStateToFab(model),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        bottomNavigationBar:
            (model.isMachineAvailable && model.hasPrinter && model.hasServer)
                ? AnimatedBottomNavigationBar(
                    // ToDo swap with Text
                    icons: [
                      FlutterIcons.tachometer_faw,
                      // FlutterIcons.camera_control_mco,
                      FlutterIcons.settings_oct,
                    ],
                    activeColor: getActiveTextColor(context),
                    gapLocation: GapLocation.end,
                    backgroundColor: Theme.of(context).primaryColor,
                    notchSmoothness: NotchSmoothness.softEdge,
                    activeIndex: model.currentIndex,
                    onTap: model.setIndex,
                  )
                : null,
        // ConvexAppBar(
        //
        //   style: TabStyle.textIn,
        //   items: [
        //     TabItem(icon: Icons.list, title: 'Info'),
        //     TabItem(icon: Icons.calendar_today, title: 'Control'),
        //     TabItem(icon: Icons.assessment, title: 'Do'),
        //   ],
        //   initialActiveIndex: model.currentIndex,
        //   onTap: model.setIndex,
        // ),
        drawer: NavigationDrawerWidget(curPath: Routes.overView),
      ),
      viewModelBuilder: () => OverViewModel(),
    );
  }

  Color? getActiveTextColor(context) {
    var themeData = Theme.of(context);
    if (themeData.brightness == Brightness.dark)
      return themeData.colorScheme.secondary;
    return Colors.white;
  }

  Widget getViewForIndex(int index) {
    switch (index) {
      case 0:
        return GeneralTab();
      case 1:
        return ControlTab();
      default:
        return GeneralTab();
    }
  }

  Widget? printingStateToFab(OverViewModel model) {
    if (!model.hasPrinter || !model.hasServer) return null;

    if (model.server.klippyState == KlipperState.error) return IdleFAB();

    switch (model.printer.print.state) {
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

class IdleFAB extends ViewModelWidget<OverViewModel> {
  const IdleFAB({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return FloatingActionButton(
        child: Icon(Icons.menu), onPressed: () => model.showNonPrintingMenu());
  }
}

class PausedFAB extends ViewModelWidget<OverViewModel> {
  const PausedFAB({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return SpeedDial(
      icon: FlutterIcons.options_vertical_sli,
      activeIcon: Icons.close,
      children: [
        SpeedDialChild(
          child: Icon(Icons.cleaning_services),
          backgroundColor: Colors.red,
          label: 'Cancel',
          onTap: model.onCancelPrintPressed,
        ),
        SpeedDialChild(
          child: Icon(Icons.play_arrow),
          backgroundColor: Colors.blue,
          label: 'Resume',
          onTap: model.onResumePrintPressed,
        ),
      ],
      spacing: 5,
      overlayOpacity: 0,
    );
  }
}
