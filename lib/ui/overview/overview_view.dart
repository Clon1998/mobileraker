import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:full_screen_menu/full_screen_menu.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/ui/connection/connectionState_view.dart';
import 'package:mobileraker/ui/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/overview/tabs/control_tab.dart';
import 'package:mobileraker/ui/overview/tabs/general_tab.dart';
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
                  color: Printer.stateToColor(model.hasServer
                      ? model.server.klippyState
                      : PrinterState.error)),
              tooltip: model.hasServer
                  ? 'Server State is ${model.server.klippyStateName} and Moonraker is ${model.server.klippyConnected ? 'connected' : 'disconnected'} to Klipper'
                  : 'Server is not connected',
              onPressed: () => null,
            ),
            IconButton(
              icon: Icon(FlutterIcons.zap_off_fea, color: Colors.red),
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
        child: Icon(Icons.menu),
        onPressed: () => FullScreenMenu.show(context, items: <Widget>[
              FSMenuItem(
                text: Text("Moonraker - Restart"),
                icon: Icon(FlutterIcons.API_ant, color: Colors.black),
                onTap: model.onRestartMoonrakerPressed,
              ),
              FSMenuItem(
                text: Text("Klipper - Restart"),
                icon: Icon(FlutterIcons.brain_faw5s, color: Colors.black),
                onTap: model.onRestartKlipperPressed,
              ),
              FSMenuItem(
                text: Text("Host - Restart"),
                icon:
                    Icon(FlutterIcons.raspberry_pi_faw5d, color: Colors.black),
                onTap: model.onRestartHostPressed,
              ),
              FSMenuItem(
                text: Text("Firmware - Restart"),
                icon: Icon(FlutterIcons.circuit_board_oct, color: Colors.black),
                onTap: model.onRestartMCUPressed,
              ),
            ]));
  }
}

class SpeedDialPaused extends ViewModelWidget<OverViewModel> {
  const SpeedDialPaused({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return SpeedDial(
      // animatedIcon: AnimatedIcons.menu_close,
      // animatedIconTheme: IconThemeData(size: 22.0),
      /// This is ignored if animatedIcon is non null
      icon: FlutterIcons.options_vertical_sli,
      activeIcon: Icons.close,
      // iconTheme: IconThemeData(color: Colors.grey[50], size: 30),
      /// The label of the main button.
      // label: Text("Open Speed Dial"),
      /// The active label of the main button, Defaults to label if not specified.
      // activeLabel: Text("Close Speed Dial"),
      /// Transition Builder between label and activeLabel, defaults to FadeTransition.
      // labelTransitionBuilder: (widget, animation) => ScaleTransition(scale: animation,child: widget),
      /// The below button size defaults to 56 itself, its the FAB size + It also affects relative padding and other elements
      buttonSize: 56.0,
      visible: true,

      /// If true user is forced to close dial manually
      /// by tapping main button and overlay is not rendered.
      closeManually: false,

      /// If true overlay will render no matter what.
      renderOverlay: false,
      // curve: Curves.bounceIn,
      overlayColor: Colors.black,
      overlayOpacity: 0.3,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 8.0,
      shape: CircleBorder(),
      // orientation: SpeedDialOrientation.Up,
      // childMarginBottom: 2,
      // childMarginTop: 2,
      children: [
        SpeedDialChild(
          child: Icon(Icons.cleaning_services),
          backgroundColor: Colors.red,
          label: 'Cancel',
          labelStyle: TextStyle(fontSize: 18.0),
          onTap: model.onCancelPrintPressed,
        ),
        SpeedDialChild(
          child: Icon(Icons.play_arrow),
          backgroundColor: Colors.blue,
          label: 'Resume',
          labelStyle: TextStyle(fontSize: 18.0),
          onTap: model.onResumePrintPressed,
        ),
      ],
    );
  }
}
