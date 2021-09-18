import 'dart:math';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:intl/intl.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/machine/temperature_preset.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/components/refresh_printer.dart';
import 'package:mobileraker/ui/views/overview/tabs/general_tab_viewmodel.dart';
import 'package:mobileraker/util/time_util.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:stacked/stacked.dart';

class GeneralTab extends ViewModelBuilderWidget<GeneralTabViewModel> {
  const GeneralTab({Key? key}) : super(key: key);

  @override
  bool get disposeViewModel => false;

  @override
  bool get initialiseSpecialViewModelsOnce => true;

  @override
  Widget builder(
      BuildContext context, GeneralTabViewModel model, Widget? child) {
    return PullToRefreshPrinter(
      child: ListView(
        padding: EdgeInsets.only(bottom: 20),
        children: [
          if (model.hasPrinter &&
              model.hasServer &&
              model.isPrinterSelected) ...[
            PrintCard(),
            TemperatureCard(),
            if (model.webCamUrl != null) CamCard(),
            if (model.printer.print.state != PrintState.printing)
              ControlXYZCard(),
            if (model.printer.print.state == PrintState.printing)
              BabySteppingCard(),
          ]
        ],
      ),
    );
  }

  @override
  GeneralTabViewModel viewModelBuilder(BuildContext context) =>
      locator<GeneralTabViewModel>();
}

class PrintCard extends ViewModelWidget<GeneralTabViewModel> {
  const PrintCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
    switch (model.printer.print.state) {
      case PrintState.printing:
        return Card(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.only(top: 3, left: 16, right: 16),
                leading: Icon(FlutterIcons.monitor_dashboard_mco),
                title: Text('${model.printer.print.stateName}'),
                subtitle: Text(
                    "Printing: ${model.printer.print.filename}\nFor: ${secondsToDurationText(model.printer.print.totalDuration)}"),
                trailing: CircularPercentIndicator(
                  radius: 50,
                  lineWidth: 4,
                  percent: model.printer.virtualSdCard.progress,
                  center: Text(
                      "${(model.printer.virtualSdCard.progress * 100).round()}%"),
                  progressColor:
                      (model.printer.print.state == PrintState.complete)
                          ? Colors.green
                          : Colors.deepOrange,
                ),
              ),
              _buildTableView(context, model),
            ],
          ),
        );

      case PrintState.error:
        return Card(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.only(top: 3, left: 16, right: 16),
                leading: Icon(FlutterIcons.monitor_dashboard_mco),
                title: Text('${model.printer.print.stateName}'),
                subtitle: Text('${model.printer.print.message}'),
              ),
              _buildTableView(context, model),
            ],
          ),
        );

      default:
        return Card(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.only(top: 3, left: 16, right: 16),
                leading: Icon(FlutterIcons.monitor_dashboard_mco),
                title: Text('${model.printer.print.stateName}'),
              ),
              _buildTableView(context, model),
            ],
          ),
        );
    }
  }

  Padding _buildTableView(BuildContext context, GeneralTabViewModel model) {
    return Padding(
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
                      Text('Todo'),
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
        ));
  }
}

class CamCard extends ViewModelWidget<GeneralTabViewModel> {
  const CamCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
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
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1,
                maxScale: 10,
                child: Transform(
                    alignment: Alignment.center,
                    transform: matrix4,
                    child: Mjpeg(
                      height: 280,
                      isLive: true,
                      stream: model.webCamUrl!,
                    )),
              )),
        ],
      ),
    );
  }
}

class TemperatureCard extends ViewModelWidget<GeneralTabViewModel> {
  const TemperatureCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
    return FlipCard(
      key: model.tmpCardKey,
      flipOnTouch: false,
      direction: FlipDirection.VERTICAL,
      front: Card(
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
              title: Text('Temperature controls'),
              trailing: TextButton(
                onPressed: () => model.flipTemperatureCard(),
                // onPressed: () => showWIPSnackbar(),
                child: Text('Presets'),
              ),
            ),
            Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var elementWidth = constraints.maxWidth / 2;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          TempTile(
                            name: 'Hotend',
                            width: constraints.maxWidth / 2,
                            current: model.printer.extruder.temperature,
                            target: model.printer.extruder.target,
                            onTap: () => model.editDialog(false),
                          ),
                          TempTile(
                            name: 'Bed',
                            width: constraints.maxWidth / 2,
                            current: model.printer.heaterBed.temperature,
                            target: model.printer.heaterBed.target,
                            onTap: () => model.editDialog(true),
                          ),
                          ...buildTempSensors(model, elementWidth)
                        ],
                      ),
                    );
                  },
                )),
          ],
        ),
      ),
      back: Card(
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
              title: Text('Temperature presets'),
              trailing: TextButton(
                onPressed: () => model.flipTemperatureCard(),
                child: Text('Sensors'),
              ),
            ),
            Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var elementWidth = constraints.maxWidth / 2;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _buildTemperaturePresetCards(
                            constraints.maxWidth / 2, model),
                      ),
                    );
                  },
                )),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTemperaturePresetCards(
      double width, GeneralTabViewModel model) {
    var coolOf = _TemperaturePresetCard(
      width: width,
      presetName: 'Cooloff',
      extruderTemp: 0,
      bedTemp: 0,
      onTap: () => model.setTemperaturePreset(0, 0),
    );

    List<TemperaturePreset> tempPresets = model.temperaturePresets;
    var presetWidgets = List.generate(tempPresets.length, (index) {
      TemperaturePreset preset = tempPresets[index];
      return _TemperaturePresetCard(
        width: width,
        presetName: preset.name,
        extruderTemp: preset.extruderTemp,
        bedTemp: preset.bedTemp,
        onTap: () =>
            model.setTemperaturePreset(preset.extruderTemp, preset.bedTemp),
      );
    });
    presetWidgets.insert(0, coolOf);
    return presetWidgets;
  }

  List<Widget> buildTempSensors(GeneralTabViewModel model, double width) {
    List<Widget> rows = [];
    var temperatureSensors = model.printer.temperatureSensors;
    for (var sensor in temperatureSensors) {
      var tr = TempTile(
        name: sensor.name,
        width: width,
        current: sensor.temperature,
        target: sensor.measuredMaxTemp,
      );
      rows.add(tr);
    }
    return rows;
  }

}

class _TemperaturePresetCard extends StatelessWidget {
  final double width;
  final String presetName;
  final int extruderTemp;
  final int bedTemp;
  final VoidCallback? onTap;

  const _TemperaturePresetCard(
      {Key? key,
      required this.width,
      required this.presetName,
      required this.extruderTemp,
      required this.bedTemp,
      required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CardWithButton(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(presetName,
                style: Theme.of(context).textTheme.headline6,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text('Extruder: $extruderTemp°C',
                style: Theme.of(context).textTheme.caption),
            Text('Bed: $bedTemp°C', style: Theme.of(context).textTheme.caption),
          ],
        ),
        buttonChild: Text("Set"),
        onTap: onTap);
  }
}

class TempTile extends StatelessWidget {
  final String name;
  final double current;
  final double target;
  final double width;
  final VoidCallback? onTap;

  // ToDO: move to viewModel?
  String get targetTemp {
    if (onTap == null) return '${target.toStringAsFixed(1)} °C max';
    if (target > 0) return '${target.toStringAsFixed(1)} °C target';
    return 'Off';
  }

  const TempTile({
    Key? key,
    required this.name,
    required this.current,
    required this.width,
    required this.target,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var col = Theme.of(context).primaryColorLight;

    if (target > 0 && onTap != null)
      col = Color.alphaBlend(
          Color.fromRGBO(178, 24, 24, 1).withOpacity(min(current / target, 1)),
          col);

    return CardWithButton(
        width: width,
        backgroundColor: col,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.caption),
            Text('${current.toStringAsFixed(1)} °C',
                style: Theme.of(context).textTheme.headline6),
            Text(targetTemp),
          ],
        ),
        buttonChild: onTap == null ? const Text('Sensor') : const Text('Set'),
        onTap: onTap);
  }
}

class ControlXYZCard extends ViewModelWidget<GeneralTabViewModel> {
  const ControlXYZCard({
    Key? key,
  }) : super(key: key, reactive: true);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
    var marginForBtns = const EdgeInsets.all(10);
    var txtBtnCOl = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
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
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              margin: marginForBtns,
                              color: Theme.of(context).accentColor,
                              height: 40,
                              width: 40,
                              child: IconButton(
                                  onPressed: () =>
                                      model.onMoveBtn(PrinterAxis.Y),
                                  icon: Icon(FlutterIcons.upsquare_ant)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              margin: marginForBtns,
                              color: Theme.of(context).accentColor,
                              height: 40,
                              width: 40,
                              child: IconButton(
                                  onPressed: () =>
                                      model.onMoveBtn(PrinterAxis.X, false),
                                  icon: Icon(FlutterIcons.leftsquare_ant)),
                            ),
                            Container(
                              margin: marginForBtns,
                              color: Theme.of(context).accentColor,
                              height: 40,
                              width: 40,
                              child: IconButton(
                                  onPressed: () => model.onHomeAxisBtn(
                                      {PrinterAxis.X, PrinterAxis.Y}),
                                  icon: Icon(FlutterIcons.home_faw5s)),
                            ),
                            Container(
                              margin: marginForBtns,
                              color: Theme.of(context).accentColor,
                              height: 40,
                              width: 40,
                              child: IconButton(
                                  onPressed: () =>
                                      model.onMoveBtn(PrinterAxis.X),
                                  icon: Icon(FlutterIcons.rightsquare_ant)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              margin: marginForBtns,
                              color: Theme.of(context).accentColor,
                              height: 40,
                              width: 40,
                              child: IconButton(
                                onPressed: () =>
                                    model.onMoveBtn(PrinterAxis.Y, false),
                                icon: Icon(FlutterIcons.downsquare_ant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Container(
                          margin: marginForBtns,
                          color: Theme.of(context).accentColor,
                          height: 40,
                          width: 40,
                          child: IconButton(
                              onPressed: () => model.onMoveBtn(PrinterAxis.Z),
                              icon: Icon(FlutterIcons.upsquare_ant)),
                        ),
                        Container(
                          margin: marginForBtns,
                          color: Theme.of(context).accentColor,
                          height: 40,
                          width: 40,
                          child: IconButton(
                              onPressed: () =>
                                  model.onHomeAxisBtn({PrinterAxis.Z}),
                              icon: Icon(FlutterIcons.home_faw5s)),
                        ),
                        Container(
                          margin: marginForBtns,
                          color: Theme.of(context).accentColor,
                          height: 40,
                          width: 40,
                          child: IconButton(
                              onPressed: () =>
                                  model.onMoveBtn(PrinterAxis.Z, false),
                              icon: Icon(FlutterIcons.downsquare_ant)),
                        ),
                      ],
                    ),
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
                              primary: txtBtnCOl),
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
                                primary: txtBtnCOl),
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
                                primary: txtBtnCOl),
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
                        selectedIndex: model.selectedIndexAxisStepSizeIndex,
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

class HomedAxisChip extends ViewModelWidget<GeneralTabViewModel> {
  const HomedAxisChip({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
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

class BabySteppingCard extends ViewModelWidget<GeneralTabViewModel> {
  const BabySteppingCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
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
                label: Text("${model.printer.zOffset.toStringAsFixed(3)}mm"),
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
                        selectedIndex: model.selectedIndexBabySteppingSize,
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
