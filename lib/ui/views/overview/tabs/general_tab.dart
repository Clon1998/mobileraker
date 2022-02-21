import 'dart:math';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:intl/intl.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/temperature_preset.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/toolhead.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/ui/components/HorizontalScrollIndicator.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/components/refresh_printer.dart';
import 'package:mobileraker/ui/views/overview/tabs/general_tab_viewmodel.dart';
import 'package:mobileraker/util/misc.dart';
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
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          if (model.isPrinterAvailable &&
              model.isServerAvailable &&
              model.isMachineAvailable &&
              !model.isBusy &&
              model.initialised) ...{
            PrintCard(),
            TemperatureCard(),
            if (model.webCamAvailable) CamCard(),
            if (model.isNotPrinting) _ControlXYZCard(),
            if (model.showBabyStepping) _BabySteppingCard(),
          }
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
    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
            leading: Icon((model.server.klippyState != KlipperState.ready ||
                    !model.server.klippyConnected)
                ? FlutterIcons.disconnect_ant
                : FlutterIcons.monitor_dashboard_mco),
            title: Text(model.status,
                style: TextStyle(
                    color: (model.server.klippyState != KlipperState.ready ||
                            !model.server.klippyConnected)
                        ? Theme.of(context).colorScheme.error
                        : null)),
            subtitle: _subTitle(model),
            trailing: _trailing(model),
          ),
          _buildTableView(context, model),
        ],
      ),
    );
  }

  Widget? _trailing(GeneralTabViewModel model) {
    switch (model.printer.print.state) {
      case PrintState.printing:
        return CircularPercentIndicator(
          radius: 50,
          lineWidth: 4,
          percent: model.printer.virtualSdCard.progress,
          center:
              Text("${(model.printer.virtualSdCard.progress * 100).round()}%"),
          progressColor: (model.printer.print.state == PrintState.complete)
              ? Colors.green
              : Colors.deepOrange,
        );
      case PrintState.error:
      case PrintState.complete:
        return TextButton.icon(
            onPressed: model.onResetPrintTap,
            icon: Icon(Icons.restart_alt_outlined),
            label: Text('Reset'));
      default:
        return null;
    }
  }

  Widget? _subTitle(GeneralTabViewModel model) {
    if (model.server.klippyState != KlipperState.ready ||
        !model.server.klippyConnected)
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: model.onRestartKlipperPressed,
            child: Text('Restart Klipper'),
          ),
          ElevatedButton(
            onPressed: model.onRestartMCUPressed,
            child: Text('Restart MCU'),
          )
        ],
      );

    switch (model.printer.print.state) {
      case PrintState.printing:
        return Text(
            "Printing: ${model.printer.print.filename}\nFor: ${secondsToDurationText(model.printer.print.totalDuration)}");
      case PrintState.error:
        return Text('${model.printer.print.message}');
      default:
        return null;
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
            if (model.isPrinting)
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
                        Text('${model.layer}/${model.maxLayers}'),
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
                            : '--:--'),
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
    const double minWebCamHeight = 280;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              FlutterIcons.webcam_mco,
            ),
            title: Text('Webcam'),
            trailing: (model.webcams.length > 1)
                ? DropdownButton(
                    value: model.selectedCam,
                    onChanged: model.onWebcamSettingSelected,
                    items: model.webcams.map((e) {
                      return DropdownMenuItem(
                        child: Text(e.name),
                        value: e,
                      );
                    }).toList())
                : null,
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Container(
                constraints: BoxConstraints(minHeight: minWebCamHeight),
                child: Stack(children: [
                  Center(
                    child: Transform(
                        alignment: Alignment.center,
                        transform: model.transformMatrix,
                        child: Mjpeg(
                          isLive: true,
                          stream: model.webCamUrl,
                        )),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: IconButton(
                        icon: Icon(Icons.aspect_ratio_outlined),
                        tooltip: 'Fullscreen',
                        onPressed: model.onFullScreenTap,
                      ),
                    ),
                  ),
                ]),
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
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
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
                  onPressed: model.flipTemperatureCard,
                  // onPressed: () => showWIPSnackbar(),
                  child: Text('Presets'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var elementWidth = constraints.maxWidth / 2;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: model.tempsScrollController,
                      child: Row(
                        children: [
                          _HeaterCard(
                            name: 'Hotend',
                            width: elementWidth,
                            current: model.printer.extruder.temperature,
                            target: model.printer.extruder.target,
                            onTap: model.canUsePrinter
                                ? () => model.editDialog(false)
                                : null,
                          ),
                          _HeaterCard(
                            name: 'Bed',
                            width: elementWidth,
                            current: model.printer.heaterBed.temperature,
                            target: model.printer.heaterBed.target,
                            onTap: model.canUsePrinter
                                ? () => model.editDialog(true)
                                : null,
                          ),
                          ..._buildTempSensors(elementWidth, model)
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (model.presetSteps > 2 || model.tempsSteps > 2)
                HorizontalScrollIndicator(
                  steps: model.tempsSteps,
                  controller: model.tempsScrollController,
                  childsPerScreen: 2,
                )
            ],
          ),
        ),
      ),
      back: Card(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
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
                  onPressed: model.flipTemperatureCard,
                  child: Text('Sensors'),
                ),
              ),
              Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: model.presetsScrollController,
                        child: Row(
                          children: _buildTemperaturePresetCards(
                              constraints.maxWidth / 2, model),
                        ),
                      );
                    },
                  )),
              if (model.presetSteps > 2 || model.tempsSteps > 2)
                HorizontalScrollIndicator(
                  steps: model.presetSteps,
                  controller: model.presetsScrollController,
                  childsPerScreen: 2,
                )
            ],
          ),
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
      onTap:
          model.canUsePrinter ? () => model.setTemperaturePreset(0, 0) : null,
    );

    List<TemperaturePreset> tempPresets = model.temperaturePresets;
    var presetWidgets = List.generate(tempPresets.length, (index) {
      TemperaturePreset preset = tempPresets[index];
      return _TemperaturePresetCard(
        width: width,
        presetName: preset.name,
        extruderTemp: preset.extruderTemp,
        bedTemp: preset.bedTemp,
        onTap: model.canUsePrinter
            ? () =>
                model.setTemperaturePreset(preset.extruderTemp, preset.bedTemp)
            : null,
      );
    });
    presetWidgets.insert(0, coolOf);
    return presetWidgets;
  }

  List<Widget> _buildTempSensors(double width, GeneralTabViewModel model) {
    List<Widget> rows = [];
    for (var sensor in model.filteredSensors) {
      _SensorCard tr = _SensorCard(
        name: beautifyName(sensor.name),
        width: width,
        current: sensor.temperature,
        max: sensor.measuredMaxTemp,
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

class _HeaterCard extends StatelessWidget {
  final String name;
  final double current;
  final double target;
  final double width;
  final VoidCallback? onTap;

  String get targetTemp =>
      target > 0 ? '${target.toStringAsFixed(1)} °C target' : 'Off';

  const _HeaterCard({
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
    var textCol = Theme.of(context).colorScheme.onSurface;
    if (target > 0 && onTap != null) {
      col = Color.alphaBlend(
          Color.fromRGBO(178, 24, 24, 1).withOpacity(min(current / target, 1)),
          col);
      textCol = Color.alphaBlend(
          Colors.white.withOpacity(min(current / target, 1)),
          Theme.of(context).colorScheme.onSecondary);
    }

    return CardWithButton(
        width: width,
        backgroundColor: col,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: Theme.of(context)
                    .textTheme
                    .caption
                    ?.copyWith(color: textCol)),
            Text('${current.toStringAsFixed(1)} °C',
                style: Theme.of(context)
                    .textTheme
                    .headline6
                    ?.copyWith(color: textCol)),
            Text(targetTemp, style: TextStyle(color: textCol)),
          ],
        ),
        buttonChild: const Text('Set'),
        onTap: onTap);
  }
}

class _SensorCard extends StatelessWidget {
  final String name;
  final double current;
  final double max;
  final double width;

  const _SensorCard({
    Key? key,
    required this.name,
    required this.current,
    required this.width,
    required this.max,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CardWithButton(
        width: width,
        backgroundColor: Theme.of(context).primaryColorLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.caption),
            Text('${current.toStringAsFixed(1)} °C',
                style: Theme.of(context).textTheme.headline6),
            Text('${max.toStringAsFixed(1)} °C max'),
          ],
        ),
        buttonChild: const Text('Sensor'),
        onTap: null);
  }
}

class _ControlXYZCard extends ViewModelWidget<GeneralTabViewModel> {
  const _ControlXYZCard({
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
            trailing: _HomedAxisChip(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              margin: marginForBtns,
                              color: Theme.of(context).colorScheme.secondary,
                              height: 40,
                              width: 40,
                              child: IconButton(
                                  onPressed: !model.canUsePrinter
                                      ? null
                                      : () => model.onMoveBtn(PrinterAxis.Y),
                                  icon: Icon(FlutterIcons.upsquare_ant)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              margin: marginForBtns,
                              color: Theme.of(context).colorScheme.secondary,
                              height: 40,
                              width: 40,
                              child: IconButton(
                                  onPressed: !model.canUsePrinter
                                      ? null
                                      : () =>
                                          model.onMoveBtn(PrinterAxis.X, false),
                                  icon: Icon(FlutterIcons.leftsquare_ant)),
                            ),
                            Container(
                              margin: marginForBtns,
                              color: Theme.of(context).colorScheme.secondary,
                              height: 40,
                              width: 40,
                              child: Tooltip(
                                message: "Home X and Y axis",
                                child: IconButton(
                                    onPressed: model.canUsePrinter
                                        ? () => model.onHomeAxisBtn(
                                            {PrinterAxis.X, PrinterAxis.Y})
                                        : null,
                                    icon: Icon(Icons.home)),
                              ),
                            ),
                            Container(
                              margin: marginForBtns,
                              color: Theme.of(context).colorScheme.secondary,
                              height: 40,
                              width: 40,
                              child: IconButton(
                                  onPressed: !model.canUsePrinter
                                      ? null
                                      : () => model.onMoveBtn(PrinterAxis.X),
                                  icon: Icon(FlutterIcons.rightsquare_ant)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              margin: marginForBtns,
                              color: Theme.of(context).colorScheme.secondary,
                              height: 40,
                              width: 40,
                              child: IconButton(
                                onPressed: !model.canUsePrinter
                                    ? null
                                    : () =>
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
                          color: Theme.of(context).colorScheme.secondary,
                          height: 40,
                          width: 40,
                          child: IconButton(
                              onPressed: !model.canUsePrinter
                                  ? null
                                  : () => model.onMoveBtn(PrinterAxis.Z),
                              icon: Icon(FlutterIcons.upsquare_ant)),
                        ),
                        Container(
                          margin: marginForBtns,
                          color: Theme.of(context).colorScheme.secondary,
                          height: 40,
                          width: 40,
                          child: Tooltip(
                            message: "Home Z axis",
                            child: IconButton(
                                onPressed: model.canUsePrinter
                                    ? () => model.onHomeAxisBtn({PrinterAxis.Z})
                                    : null,
                                icon: Icon(Icons.home)),
                          ),
                        ),
                        Container(
                          margin: marginForBtns,
                          color: Theme.of(context).colorScheme.secondary,
                          height: 40,
                          width: 40,
                          child: IconButton(
                              onPressed: !model.canUsePrinter
                                  ? null
                                  : () => model.onMoveBtn(PrinterAxis.Z, false),
                              icon: Icon(FlutterIcons.downsquare_ant)),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  margin: EdgeInsets.only(top: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Tooltip(
                        message: "Home all axis",
                        child: TextButton.icon(
                          onPressed: model.canUsePrinter
                              ? () => model.onHomeAxisBtn(
                                  {PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z})
                              : null,
                          icon: Icon(Icons.home),
                          label: Text("ALL"),
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(5.0))),
                              primary: txtBtnCOl),
                        ),
                      ),
                      if (model.printer.configFile.hasQuadGantry)
                        Tooltip(
                          message: "Run quad-gantry leveling",
                          child: TextButton.icon(
                            onPressed: !model.canUsePrinter
                                ? null
                                : model.onQuadGantry,
                            icon: Icon(FlutterIcons.quadcopter_mco),
                            label: Text("QGL"),
                            style: TextButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.secondary,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(5.0))),
                                primary: txtBtnCOl),
                          ),
                        ),
                      if (model.printer.configFile.hasBedMesh)
                        Tooltip(
                          message: "Run bed-mesh calibration",
                          child: TextButton.icon(
                            onPressed:
                                !model.canUsePrinter ? null : model.onBedMesh,
                            icon: Icon(FlutterIcons.map_marker_path_mco),
                            label: Text("MESH"),
                            style: TextButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.secondary,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(5.0))),
                                primary: txtBtnCOl),
                            // color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      Tooltip(
                        message: "Disable Motors",
                        child: TextButton.icon(
                          onPressed:
                              !model.canUsePrinter ? null : model.onMotorOff,
                          icon: Icon(Icons.near_me_disabled),
                          label: Text("M84"),
                          style: TextButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(5.0))),
                              primary: txtBtnCOl),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text("Step size [mm]"),
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

class _HomedAxisChip extends ViewModelWidget<GeneralTabViewModel> {
  const _HomedAxisChip({
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

class _BabySteppingCard extends ViewModelWidget<GeneralTabViewModel> {
  const _BabySteppingCard({
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
                      margin: const EdgeInsets.all(5),
                      child: IconButton(
                          onPressed: model.canUsePrinter
                              ? () => model.onBabyStepping()
                              : null,
                          icon: Icon(FlutterIcons.upsquare_ant)),
                      color: Theme.of(context).colorScheme.secondary,
                      height: 40,
                      width: 40,
                    ),
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: IconButton(
                          onPressed: model.canUsePrinter
                              ? () => model.onBabyStepping(false)
                              : null,
                          icon: Icon(FlutterIcons.downsquare_ant)),
                      color: Theme.of(context).colorScheme.secondary,
                      height: 40,
                      width: 40,
                    ),
                  ],
                ),
                Spacer(flex: 1),
                Column(
                  children: [
                    Text("Step size [mm]"),
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
