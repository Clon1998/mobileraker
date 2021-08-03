import 'dart:math';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:flutter_slider_drawer/flutter_slider_drawer.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:full_screen_menu/full_screen_menu.dart';
import 'package:intl/intl.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/ui/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/connection/connectionState_view.dart';
import 'package:mobileraker/util/time_util.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:stacked/stacked.dart';

import 'overview_viewmodel.dart';

class OverView extends StatelessWidget {
  const OverView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<OverViewModel>.reactive(
      builder: (context, model, child) => Scaffold(
        appBar: AppBar(
          title: Text(model.title),
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
          pChild: Center(
              child: (model.hasPrinter &&
                      model.printer.state == PrinterState.ready)
                  ? SmartRefresher(
                      controller: model.refreshController,
                      onRefresh: model.onRefresh,
                      child: ListView(
                        children: [
                          if (model.hasPrinter &&
                              model.printer.state == PrinterState.ready) ...[
                            PrintPages(),
                            ThermoPages(),
                            ControlPages(),
                          ]
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpinKitFadingCube(
                          color: Colors.orange,
                        ),
                        SizedBox(
                          height: 30,
                        ),
                        // FadingText("Fetching printer..."),
                        Text("Fetching printer ...")
                      ],
                    )),
        ),
        floatingActionButton: printingStateToFab(model),
        drawer: NavigationDrawerWidget(curPath: Routes.overView),
      ),
      viewModelBuilder: () => OverViewModel(),
    );
  }

  Widget? printingStateToFab(OverViewModel model) {
    if (!model.hasPrinter) return null;

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

class PrintPages extends ViewModelWidget<OverViewModel> {
  const PrintPages({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return ExpandablePageView(
      estimatedPageSize: 200,
      animateFirstPage: true,
      children: [PrintCard(), CamCard()],
    );
  }
}

class PrintCard extends ViewModelWidget<OverViewModel> {
  const PrintCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(FlutterIcons.monitor_dashboard_mco),
            title: Text('${model.printer.print.stateName}'),
            subtitle: (model.printer.print.state == PrintState.printing)
                ? Text(
                    "Printing ${model.printer.print.filename}\n${secondsToDurationText(model.printer.print.totalDuration)}")
                : null,
            trailing: CircularPercentIndicator(
              radius: 50,
              lineWidth: 4,
              percent: model.printer.virtualSdCard.progress,
              center: Text(
                  "${(model.printer.virtualSdCard.progress * 100).round()}%"),
              progressColor: (model.printer.print.state == PrintState.complete)
                  ? Colors.green
                  : Colors.deepOrange,
            ),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 15),
              child: Table(
                border: TableBorder(
                    horizontalInside: BorderSide(
                        width: 1,
                        color: Theme.of(context).dividerColor,
                        style: BorderStyle.solid)),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: {
                  0: FractionColumnWidth(.1),
                },
                children: [
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(FlutterIcons.axis_arrow_mco),
                    ),
                    Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text("X"),
                            Text(
                                '${model.printer.toolhead.position[0].toStringAsFixed(2)}'),
                          ],
                        )),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("Y"),
                          Text(
                              '${model.printer.toolhead.position[1].toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("Z"),
                          Text(
                              '${model.printer.toolhead.position[2].toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  ]),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(FlutterIcons.printer_3d_mco),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text("Speed"),
                            Text('${model.printer.gCodeMove.mmSpeed} mm/s'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text("Layer"),
                            Text(model.printer.toolhead.position[1]
                                .toStringAsFixed(2)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text("ETA"),
                            Text((model.printer.eta != null)
                                ? DateFormat.Hm().format(model.printer.eta!)
                                : '00:00'),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              )),
        ],
      ),
    );
  }
}

class CamCard extends ViewModelWidget<OverViewModel> {
  const CamCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    var matrix4 = Matrix4.identity()
      ..rotateX(model.webCamXSwap)
      ..rotateY(model.webCamYSwap);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              FlutterIcons.webcam_mco,
            ),
            title: Text('Webcam'),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 15),
              child: Transform(
                  alignment: Alignment.center,
                  transform: matrix4,
                  child: Mjpeg(
                    isLive: true,
                    stream: model.webCamUrl,
                  ))),
        ],
      ),
    );
  }
}

class ThermoPages extends ViewModelWidget<OverViewModel> {
  const ThermoPages({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return ExpandablePageView(
      estimatedPageSize: 200,
      animateFirstPage: true,
      children: [HeaterCard(), FanCard(), PinCard()],
    );
  }
}

class HeaterCard extends ViewModelWidget<OverViewModel> {
  const HeaterCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              FlutterIcons.fire_alt_faw5s,
              color: ((model.printer.extruder.target +
                          model.printer.heaterBed.target) >
                      0)
                  ? Colors.deepOrange
                  : Theme.of(context).iconTheme.color,
            ),
            title: Text('Heaters'),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 15),
              child: Table(
                border: TableBorder(
                    horizontalInside: BorderSide(
                        width: 1,
                        color: Theme.of(context).dividerColor,
                        style: BorderStyle.solid)),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: {
                  0: FractionColumnWidth(.1),
                },
                children: [
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: Icon(FlutterIcons.printer_3d_nozzle_mco),
                        onPressed: () => model.editDialog(false),
                        color: Color.alphaBlend(
                            Colors.deepOrange
                                .withOpacity(model.printer.extruder.power),
                            Theme.of(context).iconTheme.color!),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Extruder"),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("Current"),
                          Text(
                              '${model.printer.extruder.temperature.toStringAsFixed(1)}°C'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("Target"),
                          Text(
                              '${model.printer.extruder.target.toStringAsFixed(1)}°C'),
                        ],
                      ),
                    ),
                  ]),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton(
                          icon: Icon(FlutterIcons.radiator_mco),
                          onPressed: () => model.editDialog(true),
                          color: Color.alphaBlend(
                              Colors.deepOrange
                                  .withOpacity(model.printer.heaterBed.power),
                              Theme.of(context).iconTheme.color!),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("Heated Bed"),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text("Current"),
                            Text(
                                '${model.printer.heaterBed.temperature.toStringAsFixed(2)}°C'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text("Target"),
                            Text(
                                '${model.printer.heaterBed.target.toStringAsFixed(2)}°C'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ...buildTempSensors(model, context)
                ],
              )),
        ],
      ),
    );
  }
}

List<TableRow> buildTempSensors(OverViewModel model, BuildContext context) {
  List<TableRow> rows = [];
  var temperatureSensors = model.printer.temperatureSensors;
  for (var sensor in temperatureSensors) {
    var tr = TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(FlutterIcons.thermometer_faw,
              color: Theme.of(context).iconTheme.color!),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("${sensor.name}"),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("Current"),
              Text('${sensor.temperature.toStringAsFixed(1)}°C'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("Max"),
              Text('${sensor.measuredMaxTemp.toStringAsFixed(1)}°C '),
            ],
          ),
        ),
      ],
    );
    rows.add(tr);
  }
  return rows;
}

class FanCard extends ViewModelWidget<OverViewModel> {
  const FanCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              FlutterIcons.fan_mco,
              color: Theme.of(context).iconTheme.color,
            ),
            title:
                Text("Fan${(model.printer.heaterFans.length > 0) ? 's' : ''}"),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 15),
              child: Table(
                border: TableBorder(
                    horizontalInside: BorderSide(
                        width: 1,
                        color: Theme.of(context).dividerColor,
                        style: BorderStyle.solid)),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: {
                  0: FractionColumnWidth(.1),
                },
                children: buildFans(model, context),
              )),
        ],
      ),
    );
  }

  List<TableRow> buildFans(OverViewModel model, BuildContext context) {
    List<TableRow> rows = [];

    var printFan = model.printer.printFan;
    rows.add(_fanRow(model,
        speed: printFan.speed,
        name: "Part cooling",
        onSlider: model.onPartFanSlider,
        controllable: true));

    for (HeaterFan fan in model.printer.heaterFans) {
      var row = _fanRow(model, speed: fan.speed, name: fan.name);
      rows.add(row);
    }

    return rows;
  }

  TableRow _fanRow(OverViewModel model,
      {required double speed,
      required String name,
      IconData? icon,
      bool controllable = false,
      Function? onSlider}) {
    Widget w;
    if (icon != null) {
      w = Icon(icon);
    } else {
      w = speed > 0 ? SpinningFan() : Icon(FlutterIcons.fan_off_mco);
    }

    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 4, 8, 4),
        child: w,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 4, 8, 4),
        child: Text(name),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 4, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("${(speed * 100).round()}%"),
            Slider(
                value: speed,
                onChanged: (controllable && onSlider != null)
                    ? (v) => onSlider(v)
                    : null),
          ],
        ),
      ),
    ]);
  }
}

class SpinningFan extends StatefulWidget {
  @override
  _SpinningFanState createState() => _SpinningFanState();
}

class _SpinningFanState extends State<SpinningFan>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  _SpinningFanState() {
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animation,
      child: Icon(FlutterIcons.fan_mco),
    );
  }
}

class PinCard extends ViewModelWidget<OverViewModel> {
  const PinCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              FlutterIcons.fan_mco,
              color: Theme.of(context).iconTheme.color,
            ),
            title: Text(
                "Output Pin${(model.printer.outputPins.length > 0) ? 's' : ''}"),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 15),
              child: Table(
                border: TableBorder(
                    horizontalInside: BorderSide(
                        width: 1,
                        color: Theme.of(context).dividerColor,
                        style: BorderStyle.solid)),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: {
                  0: FractionColumnWidth(.1),
                },
                children: buildPin(model, context),
              )),
        ],
      ),
    );
  }

  List<TableRow> buildPin(OverViewModel model, BuildContext context) {
    List<TableRow> rows = [];

    for (var pin in model.printer.outputPins) {
      var row = _pinRow(model, name: pin.name, value: pin.value);
      rows.add(row);
    }

    return rows;
  }

  TableRow _pinRow(
    OverViewModel model, {
    required String name,
    required double value,
  }) {
    Widget w = Icon(FlutterIcons.microchip_faw);

    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 4, 8, 4),
        child: w,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 4, 8, 4),
        child: Text(name),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 4, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("${(value * 100).round()}%"),
            Slider(value: value, onChanged: null),
          ],
        ),
      ),
    ]);
  }
}

class ControlPages extends ViewModelWidget<OverViewModel> {
  const ControlPages({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return ExpandablePageView(
      estimatedPageSize: 300,
      animateFirstPage: true,
      children: [
        if (model.printer.print.state != PrintState.printing) ...[
          ControlXYZCard(),
          ExtruderControlCard(),
        ],
        GcodeMacroCard(),
        if (model.printer.print.state == PrintState.printing)
          BabySteppingCard(),
      ],
    );
  }
}

class ControlXYZCard extends ViewModelWidget<OverViewModel> {
  const ControlXYZCard({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(FlutterIcons.axis_arrow_mco),
            title: Text('Move Axis'),
            trailing: HomedAxisChip(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Column(
              children: [
                Row(
                  children: <Widget>[
                    Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              margin: EdgeInsets.all(5),
                              child: IconButton(
                                  onPressed: () =>
                                      model.onMoveBtn(PrinterAxis.Y),
                                  icon: Icon(FlutterIcons.upsquare_ant)),
                              color: Theme.of(context).accentColor,
                              height: 40,
                              width: 40,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                                margin: EdgeInsets.all(5),
                                child: IconButton(
                                    onPressed: () =>
                                        model.onMoveBtn(PrinterAxis.X, false),
                                    icon: Icon(FlutterIcons.leftsquare_ant)),
                                color: Theme.of(context).accentColor,
                                height: 40,
                                width: 40),
                            Container(
                              margin: EdgeInsets.all(5),
                              child: IconButton(
                                  onPressed: () => model.onHomeAxisBtn(
                                      {PrinterAxis.X, PrinterAxis.Y}),
                                  icon: Icon(FlutterIcons.home_faw5s)),
                              color: Theme.of(context).accentColor,
                              height: 40,
                              width: 40,
                            ),
                            Container(
                              margin: EdgeInsets.all(5),
                              child: IconButton(
                                  onPressed: () =>
                                      model.onMoveBtn(PrinterAxis.X),
                                  icon: Icon(FlutterIcons.rightsquare_ant)),
                              color: Theme.of(context).accentColor,
                              height: 40,
                              width: 40,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              margin: EdgeInsets.all(5),
                              child: IconButton(
                                onPressed: () =>
                                    model.onMoveBtn(PrinterAxis.Y, false),
                                icon: Icon(FlutterIcons.downsquare_ant),
                              ),
                              color: Theme.of(context).accentColor,
                              height: 40,
                              width: 40,
                            ),
                          ],
                        ),
                      ],
                    ),
                    Spacer(flex: 1),
                    Column(
                      children: [
                        Container(
                          margin: EdgeInsets.all(5),
                          child: IconButton(
                              onPressed: () => model.onMoveBtn(PrinterAxis.Z),
                              icon: Icon(FlutterIcons.upsquare_ant)),
                          color: Theme.of(context).accentColor,
                          height: 40,
                          width: 40,
                        ),
                        Container(
                          margin: EdgeInsets.all(5),
                          child: IconButton(
                              onPressed: () =>
                                  model.onHomeAxisBtn({PrinterAxis.Z}),
                              icon: Icon(FlutterIcons.home_faw5s)),
                          color: Theme.of(context).accentColor,
                          height: 40,
                          width: 40,
                        ),
                        Container(
                          margin: EdgeInsets.all(5),
                          child: IconButton(
                              onPressed: () =>
                                  model.onMoveBtn(PrinterAxis.Z, false),
                              icon: Icon(FlutterIcons.downsquare_ant)),
                          color: Theme.of(context).accentColor,
                          height: 40,
                          width: 40,
                        ),
                      ],
                    ),
                    Spacer(flex: 3),
                    Column(
                      children: [
                        TextButton.icon(
                          onPressed: () => model.onHomeAxisBtn(
                              {PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z}),
                          icon: Icon(FlutterIcons.home_faw5s),
                          label: Text("ALL"),
                          style: TextButton.styleFrom(
                              backgroundColor: Theme.of(context).accentColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(5.0))),
                              primary: Colors.black),
                        ),
                        if (model.printer.configFile.hasQuadGantry)
                          TextButton.icon(
                            onPressed: model.onQuadGantry,
                            icon: Icon(FlutterIcons.quadcopter_mco),
                            label: Text("QGL"),
                            style: TextButton.styleFrom(
                                backgroundColor: Theme.of(context).accentColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(5.0))),
                                primary: Colors.black),
                          ),
                        if (model.printer.configFile.hasBedMesh)
                          TextButton.icon(
                            onPressed: () => model.onBedMesh(),
                            icon: Icon(FlutterIcons.map_marker_path_mco),
                            label: Text("MESH"),
                            style: TextButton.styleFrom(
                                backgroundColor: Theme.of(context).accentColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(5.0))),
                                primary: Colors.black),
                            // color: Theme.of(context).accentColor,
                          ),
                      ],
                    ),
                  ],
                ),
                Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text("Step size:"),
                    RangeSelector(
                        onSelected: model.onSelectedAxisStepSizeChanged,
                        values: model.axisStepSize
                            .map((e) => e.toString())
                            .toList())
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomedAxisChip extends ViewModelWidget<OverViewModel> {
  const HomedAxisChip({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return Chip(
      avatar: Icon(
        FlutterIcons.shield_home_mco,
        color: Theme.of(context).iconTheme.color,
        size: 20,
      ),
      label: Text(_homedChipTitle(model.printer.toolhead.homedAxes)),
      backgroundColor: (model.printer.toolhead.homedAxes.isNotEmpty)
          ? Colors.lightGreen
          : Colors.orangeAccent,
    );
  }

  String _homedChipTitle(Set<PrinterAxis> homedAxes) {
    if (homedAxes.isEmpty)
      return 'NONE';
    else {
      List<PrinterAxis> l = homedAxes.toList();
      l.sort((a, b) => a.index.compareTo(b.index));
      return l.map((e) => EnumToString.convertToString(e)).join();
    }
  }
}

class BabySteppingCard extends ViewModelWidget<OverViewModel> {
  const BabySteppingCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
              leading: Icon(FlutterIcons.align_vertical_middle_ent),
              title: Text('Babystepping Z-Axis'),
              trailing: Chip(
                avatar: Icon(
                  FlutterIcons.progress_wrench_mco,
                  color: Theme.of(context).iconTheme.color,
                  size: 20,
                ),
                label: Text("${model.printer.zOffset.toStringAsFixed(2)}mm"),
                // ViewModelBuilder.reactive(
                //     builder: (context, model, child) => Text("0.000 mm"),
                //     viewModelBuilder: () => model),
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Row(
              children: <Widget>[
                Column(
                  children: [
                    Container(
                      margin: EdgeInsets.all(5),
                      child: IconButton(
                          onPressed: () => model.onBabyStepping(),
                          icon: Icon(FlutterIcons.upsquare_ant)),
                      color: Theme.of(context).accentColor,
                      height: 40,
                      width: 40,
                    ),
                    Container(
                      margin: EdgeInsets.all(5),
                      child: IconButton(
                          onPressed: () => model.onBabyStepping(false),
                          icon: Icon(FlutterIcons.downsquare_ant)),
                      color: Theme.of(context).accentColor,
                      height: 40,
                      width: 40,
                    ),
                  ],
                ),
                Spacer(flex: 1),
                Column(
                  children: [
                    Text("Step size"),
                    RangeSelector(
                        onSelected: model.onSelectedBabySteppingSizeChanged,
                        values: model.babySteppingSizes
                            .map((e) => e.toString())
                            .toList()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String homedChipTitle(Set<PrinterAxis> homedAxes) {
    if (homedAxes.isEmpty)
      return 'NONE';
    else {
      List<PrinterAxis> l = homedAxes.toList();
      l.sort((a, b) => a.index.compareTo(b.index));
      return l.map((e) => EnumToString.convertToString(e)).join();
    }
  }
}

class ExtruderControlCard extends ViewModelWidget<OverViewModel> {
  const ExtruderControlCard({
    Key? key,
  }) : super(key: key, reactive: false);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
            title: Text('Extruder'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Row(
              children: <Widget>[
                Column(
                  children: [
                    Container(
                      margin: EdgeInsets.all(5),
                      child: TextButton.icon(
                        onPressed: model.onDeRetractBtn,
                        icon: Icon(FlutterIcons.plus_ant),
                        label: Text("Extrude"),
                        style: TextButton.styleFrom(
                            backgroundColor: Theme.of(context).accentColor,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5.0))),
                            primary: Colors.black),
                      ),
                      color: Theme.of(context).accentColor,
                    ),
                    Container(
                      margin: EdgeInsets.all(5),
                      child: TextButton.icon(
                        onPressed: model.onRetractBtn,
                        icon: Icon(FlutterIcons.minus_ant),
                        label: Text("Retract"),
                        style: TextButton.styleFrom(
                            backgroundColor: Theme.of(context).accentColor,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5.0))),
                            primary: Colors.black),
                      ),
                      color: Theme.of(context).accentColor,
                    ),
                  ],
                ),
                Spacer(flex: 1),
                Column(
                  children: [
                    Text("Extrude length [mm]"),
                    RangeSelector(
                        onSelected: model.onSelectedRetractChanged,
                        values: model.retractLengths
                            .map((e) => e.toString())
                            .toList())
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String homedChipTitle(Set<PrinterAxis> homedAxes) {
    if (homedAxes.isEmpty)
      return 'NONE';
    else {
      List<PrinterAxis> l = homedAxes.toList();
      l.sort((a, b) => a.index.compareTo(b.index));
      return l.map((e) => EnumToString.convertToString(e)).join();
    }
  }
}

class GcodeMacroCard extends ViewModelWidget<OverViewModel> {
  const GcodeMacroCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, OverViewModel model) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(FlutterIcons.code_braces_mco),
            title: Text('Gcode-Macros'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Wrap(
              spacing: 5.0,
              children: _generateGCodeChips(model),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _generateGCodeChips(OverViewModel model) {
    return List<Widget>.generate(
      model.printer.gcodeMacros.length,
      (int index) {
        String macro = model.printer.gcodeMacros[index];
        return ActionChip(
          label: Text(macro.replaceAll("_", " ")),
          onPressed: () => model.onMacroPressed(index),
        );
      },
    ).toList();
  }
}
