import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/ui/components/connection/connectionState_view.dart';
import 'package:mobileraker/ui/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/views/overview/tabs/control_tab.dart';
import 'package:mobileraker/ui/views/overview/tabs/general_tab.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:simple_speed_dial/simple_speed_dial.dart';
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
                  color: Printer.stateToColor(model.hasServer
                      ? model.server.klippyState
                      : PrinterState.error)),
              tooltip: model.hasServer
                  ? 'Server State is ${model.server.klippyStateName} and Moonraker is ${model.server.klippyConnected ? 'connected' : 'disconnected'} to Klipper'
                  : 'Server is not connected',
              onPressed: () => null,
            ),
            IconButton(
              icon: Icon(
                Icons.dangerous_outlined,
                color: Colors.red,
                size: 30,
              ),
              tooltip: 'Emergency-Stop',
              onPressed: model.onEmergencyPressed,
            ),
          ],
        ),
        body: ConnectionStateView(
          pChild:
              (model.hasPrinter && model.printer.state == PrinterState.ready)
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
        bottomNavigationBar: (model.isPrinterSelected)
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
    if (themeData.brightness == Brightness.dark) return themeData.accentColor;
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

    if (model.server.klippyState == PrinterState.error) return null;

    switch (model.printer.print.state) {
      case PrintState.printing:
        return FloatingActionButton(
          onPressed: model.onPausePrintPressed,
          child: Icon(Icons.pause),
        );
      case PrintState.paused:
        return SpeedDialPaused();
      default:
        return MenuNonPrinting();
    }
  }
}

class MenuNonPrinting extends ViewModelWidget<OverViewModel> {
  const MenuNonPrinting({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return FloatingActionButton(
        child: Icon(Icons.menu), onPressed: () => model.showNonPrintingMenu());
  }
}

class SpeedDialPaused extends ViewModelWidget<OverViewModel> {
  const SpeedDialPaused({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return SpeedDial(
      child: Icon(FlutterIcons.options_vertical_sli),
      speedDialChildren: [
        SpeedDialChild(
          child: Icon(Icons.cleaning_services),
          backgroundColor: Colors.red,
          label: 'Cancel',
          onPressed: model.onCancelPrintPressed,
        ),
        SpeedDialChild(
          child: Icon(Icons.play_arrow),
          backgroundColor: Colors.blue,
          label: 'Resume',
          onPressed: model.onResumePrintPressed,
        ),
      ],
    );

    //   SpeedDial(
    //
    //   child:  FlutterIcons.options_vertical_sli,
    //   activeIcon: Icons.close,
    //    visible: true,
    //
    //   /// If true user is forced to close dial manually
    //   /// by tapping main button and overlay is not rendered.
    //   closeManually: false,
    //
    //   /// If true overlay will render no matter what.
    //   renderOverlay: false,
    //   // curve: Curves.bounceIn,
    //   overlayColor: Colors.black,
    //   overlayOpacity: 0.3,
    //   backgroundColor: Colors.white,
    //   foregroundColor: Colors.black,
    //   elevation: 8.0,
    //   shape: CircleBorder(),
    //   // orientation: SpeedDialOrientation.Up,
    //   // childMarginBottom: 2,
    //   // childMarginTop: 2,
    //   children: [
    //     SpeedDialChild(
    //       child: Icon(Icons.cleaning_services),
    //       backgroundColor: Colors.red,
    //       label: 'Cancel',
    //       labelStyle: TextStyle(fontSize: 18.0),
    //       onTap: model.onCancelPrintPressed,
    //     ),
    //     SpeedDialChild(
    //       child: Icon(Icons.play_arrow),
    //       backgroundColor: Colors.blue,
    //       label: 'Resume',
    //       labelStyle: TextStyle(fontSize: 18.0),
    //       onTap: model.onResumePrintPressed,
    //     ),
    //   ],
    // );
  }
}
