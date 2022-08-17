import 'dart:math';

import 'package:ditredi/ditredi.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/data/model/moonraker_db/temperature_preset.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/graph_card_with_button.dart';
import 'package:mobileraker/ui/components/mjpeg.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/components/refresh_printer.dart';
import 'package:mobileraker/ui/views/dashboard/tabs/general_tab_viewmodel.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:mobileraker/util/time_util.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';
import 'package:stringr/stringr.dart';

class GeneralTab extends ViewModelBuilderWidget<GeneralTabViewModel> {
  const GeneralTab({Key? key}) : super(key: key);

  @override
  bool get disposeViewModel => false;

  @override
  bool get initialiseSpecialViewModelsOnce => true;

  @override
  Widget builder(
      BuildContext context, GeneralTabViewModel model, Widget? child) {
    if (!model.isDataReady) {
      return const _FetchingData();
    }

    return PullToRefreshPrinter(
      child: ListView(
        key: const PageStorageKey('gTab'),
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          const PrintCard(),
          const TemperatureCard(),
          if (model.webCamAvailable) const CamCard(),
          if (model.isNotPrinting) const _ControlXYZCard(),
          if (model.showBabyStepping) const _BabySteppingCard(),
        ],
      ),
    );
  }

  @override
  GeneralTabViewModel viewModelBuilder(BuildContext context) =>
      locator<GeneralTabViewModel>();
}

class _FetchingData extends StatelessWidget {
  const _FetchingData({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitRipple(
            color: Theme.of(context).colorScheme.secondary,
            size: 100,
          ),
          const SizedBox(
            height: 30,
          ),
          FadingText('Fetching printer data'),
          // Text('Fetching printer ...')
        ],
      ),
    );
  }
}

class PrintCard extends ViewModelWidget<GeneralTabViewModel> {
  const PrintCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
    var themeData = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
            leading: Icon(
                (model.klippyInstance.klippyState != KlipperState.ready ||
                        !model.klippyInstance.klippyConnected)
                    ? FlutterIcons.disconnect_ant
                    : FlutterIcons.monitor_dashboard_mco),
            title: Text(model.status,
                style: TextStyle(
                    color: (model.klippyInstance.klippyState !=
                                KlipperState.ready ||
                            !model.klippyInstance.klippyConnected)
                        ? themeData.colorScheme.error
                        : null)),
            subtitle: _subTitle(model),
            trailing: _trailing(model),
          ),
          if (model.klippyInstance.klippyState != KlipperState.ready ||
              !model.klippyInstance.klippyConnected)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: model.onRestartKlipperPressed,
                  child: const Text('pages.dashboard.general.restart_klipper')
                      .tr(),
                ),
                ElevatedButton(
                  onPressed: model.onRestartMCUPressed,
                  child: const Text('pages.dashboard.general.restart_mcu').tr(),
                )
              ],
            ),
          if (model.isPrintingOrPaused &&
              model.printerData.excludeObject.available)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
              child: Row(
                children: [
                  IconButton(
                    color: themeData.colorScheme.primary,
                    icon: const Icon(Icons.token),
                    tooltip: 'dialogs.exclude_object.title'.tr(),
                    onPressed: model.onExcludeObjectPressed,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                                'pages.dashboard.general.print_card.current_object')
                            .tr(),
                        Text(
                          model.printerData.excludeObject.currentObject ??
                              'general.none'.tr(),
                          style: themeData.textTheme.bodyText2?.copyWith(
                              color: themeData.textTheme.caption?.color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (model.isPrintingOrPaused) ...[
            const Divider(
              thickness: 1,
              height: 0,
            ),
            const MoveTable()
          ],
        ],
      ),
    );
  }

  Widget? _trailing(GeneralTabViewModel model) {
    switch (model.printerData.print.state) {
      case PrintState.printing:
        return CircularPercentIndicator(
          radius: 25,
          lineWidth: 4,
          percent: model.printerData.virtualSdCard.progress,
          center: Text(
              '${(model.printerData.virtualSdCard.progress * 100).round()}%'),
          progressColor: (model.printerData.print.state == PrintState.complete)
              ? Colors.green
              : Colors.deepOrange,
        );
      case PrintState.error:
      case PrintState.complete:
        return TextButton.icon(
            onPressed: model.onResetPrintTap,
            icon: const Icon(Icons.restart_alt_outlined),
            label: const Text('pages.dashboard.general.print_card.reset').tr());
      default:
        return null;
    }
  }

  Widget? _subTitle(GeneralTabViewModel model) {
    switch (model.printerData.print.state) {
      case PrintState.printing:
        return Text('pages.dashboard.general.print_card.printing_for')
            .tr(args: [
          model.printerData.print.filename,
          secondsToDurationText(model.printerData.print.totalDuration)
        ]);
      case PrintState.error:
        return Text('${model.printerData.print.message}');
      default:
        return null;
    }
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
            leading: const Icon(
              FlutterIcons.webcam_mco,
            ),
            title: const Text('pages.dashboard.general.cam_card.webcam').tr(),
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
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            constraints: const BoxConstraints(minHeight: minWebCamHeight),
            child: Center(
                child: Mjpeg(
              key: ValueKey(model.selectedCam),
              imageBuilder: _imageBuilder,
              targetFps: model.selectedCam!.targetFps,
              feedUri: model.selectedCam!.url,
              transform: model.selectedCam!.transformMatrix,
              camMode: model.selectedCam!.mode,
              showFps: true,
              stackChildren: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.aspect_ratio),
                      tooltip:
                          'pages.dashboard.general.cam_card.fullscreen'.tr(),
                      onPressed: model.onFullScreenTap,
                    ),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _imageBuilder(BuildContext context, Widget imageTransformed) {
    return ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        child: imageTransformed);
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
      front: const _Heaters(),
      back: const _Presets(),
    );
  }
}

class _Heaters extends ViewModelWidget<GeneralTabViewModel> {
  const _Heaters({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                FlutterIcons.fire_alt_faw5s,
                color: ((model.printerData.extruder.target +
                            model.printerData.heaterBed.target) >
                        0)
                    ? Colors.deepOrange
                    : null,
              ),
              title: Text('pages.dashboard.general.temp_card.title').tr(),
              trailing: TextButton(
                onPressed: model.flipTemperatureCard,
                // onPressed: () => showWIPSnackbar(),
                child:
                    Text('pages.dashboard.general.temp_card.presets_btn').tr(),
              ),
            ),
            const _HeatersHorizontalScroll(),
          ],
        ),
      ),
    );
  }
}

class _HeatersHorizontalScroll extends ViewModelWidget<GeneralTabViewModel> {
  const _HeatersHorizontalScroll({Key? key}) : super(key: key);

  List<FlSpot> convertToPlotSpots(List<double>? doubles) {
    if (doubles == null) return const [];
    List<double> sublist = doubles.sublist(max(0, doubles.length - 300));
    return sublist.mapIndexed((e, i) => FlSpot(i.toDouble(), e)).toList();
  }

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
    final String extruderNameStr =
        tr('pages.dashboard.control.extrude_card.title');
    return AdaptiveHorizontalScroll(
      pageStorageKey: "temps",
      children: [
        ...model.printerData.extruders.mapIndex((e, i) => _HeaterCard(
              name: i > 0 ? '$extruderNameStr $i' : extruderNameStr,
              current: e!.temperature,
              target: e.target,
              spots: model.extrudersKeepers[e.num]?.spots ?? const [],
              onTap: model.klippyCanReceiveCommands
                  ? () => model.editExtruderHeater(i)
                  : null,
            )),
        _HeaterCard(
          name: 'pages.dashboard.general.temp_card.bed'.tr(),
          current: model.printerData.heaterBed.temperature,
          target: model.printerData.heaterBed.target,
          spots: model.heatedBedKeeper.spots,
          onTap: model.klippyCanReceiveCommands ? model.editHeatedBed : null,
        ),
        for (var sensor in model.filteredSensors)
          _SensorCard(
            name: beautifyName(sensor.name),
            current: sensor.temperature,
            max: sensor.measuredMaxTemp,
            spots: model.sensorsKeepers[sensor.name]?.spots ?? const [],
          )
      ],
    );
  }
}

class _HeaterCard extends StatelessWidget {
  static const int _stillHotTemp = 50;

  final String name;
  final double current;
  final double target;
  final List<FlSpot> spots;
  final VoidCallback? onTap;

  String get targetTemp => target > 0
      ? 'pages.dashboard.general.temp_card.heater_on'
          .tr(args: [target.toStringAsFixed(1)])
      : 'general.off'.tr();

  const _HeaterCard({
    Key? key,
    required this.name,
    required this.current,
    required this.target,
    required this.spots,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    Color colorBg = themeData.colorScheme.surfaceVariant;
    if (target > 0 && onTap != null) {
      colorBg = Color.alphaBlend(
          Color.fromRGBO(178, 24, 24, 1).withOpacity(min(current / target, 1)),
          colorBg);
    } else if (current > _stillHotTemp) {
      colorBg = Color.alphaBlend(
          Color.fromRGBO(243, 106, 65, 1.0)
              .withOpacity(min(current / _stillHotTemp - 1, 1)),
          colorBg);
    }
    return GraphCardWithButton(
        backgroundColor: colorBg,
        plotSpots: spots,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: themeData.textTheme.caption),
                Text('${current.toStringAsFixed(1)} °C',
                    style: themeData.textTheme.headline6),
                Text(targetTemp),
              ],
            ),
            AnimatedOpacity(
              opacity: current > _stillHotTemp ? 1 : 0,
              duration: kThemeAnimationDuration,
              child: Tooltip(
                message: '$name is still hot!',
                child: const Icon(Icons.do_not_touch_outlined),
              ),
            )
          ],
        ),
        buttonChild: const Text('general.set').tr(),
        onTap: onTap);
  }
}

class _Presets extends ViewModelWidget<GeneralTabViewModel> {
  const _Presets({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                FlutterIcons.fire_alt_faw5s,
                color: ((model.printerData.extruder.target +
                            model.printerData.heaterBed.target) >
                        0)
                    ? Colors.deepOrange
                    : null,
              ),
              title:
                  const Text('pages.dashboard.general.temp_card.temp_presets')
                      .tr(),
              trailing: TextButton(
                onPressed: model.flipTemperatureCard,
                child: const Text('pages.dashboard.general.temp_card.sensors')
                    .tr(),
              ),
            ),
            _TemperaturePresetsHorizontalScroll()
          ],
        ),
      ),
    );
  }
}

class _TemperaturePresetsHorizontalScroll
    extends ViewModelWidget<GeneralTabViewModel> {
  const _TemperaturePresetsHorizontalScroll({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
    var coolOf = _TemperaturePresetCard(
      presetName: 'pages.dashboard.general.temp_preset_card.cooloff'.tr(),
      extruderTemp: 0,
      bedTemp: 0,
      onTap: model.klippyCanReceiveCommands
          ? () => model.adjustNozzleAndBed(0, 0)
          : null,
    );

    List<TemperaturePreset> tempPresets = model.temperaturePresets;
    var presetWidgets = List.generate(tempPresets.length, (index) {
      TemperaturePreset preset = tempPresets[index];
      return _TemperaturePresetCard(
        presetName: preset.name,
        extruderTemp: preset.extruderTemp,
        bedTemp: preset.bedTemp,
        onTap: model.klippyCanReceiveCommands
            ? () =>
                model.adjustNozzleAndBed(preset.extruderTemp, preset.bedTemp)
            : null,
      );
    });
    presetWidgets.insert(0, coolOf);

    return AdaptiveHorizontalScroll(
      pageStorageKey: "presets",
      children: presetWidgets,
    );
  }
}

class _TemperaturePresetCard extends StatelessWidget {
  final String presetName;
  final int extruderTemp;
  final int bedTemp;
  final VoidCallback? onTap;

  const _TemperaturePresetCard(
      {Key? key,
      required this.presetName,
      required this.extruderTemp,
      required this.bedTemp,
      required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CardWithButton(
        child: Builder(builder: (context) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(presetName,
                  style: Theme.of(context).textTheme.headline6,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text('pages.dashboard.general.temp_preset_card.h_temp',
                      style: Theme.of(context).textTheme.caption)
                  .tr(args: [extruderTemp.toString()]),
              Text('pages.dashboard.general.temp_preset_card.b_temp',
                      style: Theme.of(context).textTheme.caption)
                  .tr(args: [bedTemp.toString()]),
            ],
          );
        }),
        buttonChild: const Text('general.set').tr(),
        onTap: onTap);
  }
}

class _SensorCard extends StatelessWidget {
  final String name;
  final double current;
  final double max;
  final List<FlSpot> spots;

  const _SensorCard(
      {Key? key,
      required this.name,
      required this.current,
      required this.max,
      required this.spots})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GraphCardWithButton(
      plotSpots: spots,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.caption),
          Text('${current.toStringAsFixed(1)} °C',
              style: Theme.of(context).textTheme.headline6),
          Text(
            '${max.toStringAsFixed(1)} °C max',
          ),
        ],
      ),
      buttonChild:
          const Text('pages.dashboard.general.temp_card.btn_thermistor').tr(),
      onTap: null,
    );
  }
}

class _ControlXYZCard extends ViewModelWidget<GeneralTabViewModel> {
  static const marginForBtns = const EdgeInsets.all(10);

  const _ControlXYZCard({
    Key? key,
  }) : super(key: key, reactive: true);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(FlutterIcons.axis_arrow_mco),
            title: const Text('pages.dashboard.general.move_card.title').tr(),
            trailing: const _HomedAxisChip(),
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
                              height: 40,
                              width: 40,
                              child: ElevatedButton(
                                  onPressed: !model.klippyCanReceiveCommands
                                      ? null
                                      : () => model.onMoveBtn(PrinterAxis.Y),
                                  child: const Icon(FlutterIcons.upsquare_ant)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              margin: marginForBtns,
                              height: 40,
                              width: 40,
                              child: ElevatedButton(
                                  onPressed: !model.klippyCanReceiveCommands
                                      ? null
                                      : () =>
                                          model.onMoveBtn(PrinterAxis.X, false),
                                  child:
                                      const Icon(FlutterIcons.leftsquare_ant)),
                            ),
                            Container(
                              margin: marginForBtns,
                              height: 40,
                              width: 40,
                              child: Tooltip(
                                message:
                                    'pages.dashboard.general.move_card.home_xy_tooltip'
                                        .tr(),
                                child: ElevatedButton(
                                    onPressed: model.klippyCanReceiveCommands
                                        ? () => model.onHomeAxisBtn(
                                            {PrinterAxis.X, PrinterAxis.Y})
                                        : null,
                                    child: const Icon(Icons.home)),
                              ),
                            ),
                            Container(
                              margin: marginForBtns,
                              height: 40,
                              width: 40,
                              child: ElevatedButton(
                                  onPressed: !model.klippyCanReceiveCommands
                                      ? null
                                      : () => model.onMoveBtn(PrinterAxis.X),
                                  child:
                                      const Icon(FlutterIcons.rightsquare_ant)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              margin: marginForBtns,
                              height: 40,
                              width: 40,
                              child: ElevatedButton(
                                onPressed: !model.klippyCanReceiveCommands
                                    ? null
                                    : () =>
                                        model.onMoveBtn(PrinterAxis.Y, false),
                                child: const Icon(FlutterIcons.downsquare_ant),
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
                          height: 40,
                          width: 40,
                          child: ElevatedButton(
                              onPressed: !model.klippyCanReceiveCommands
                                  ? null
                                  : () => model.onMoveBtn(PrinterAxis.Z),
                              child: const Icon(FlutterIcons.upsquare_ant)),
                        ),
                        Container(
                          margin: marginForBtns,
                          height: 40,
                          width: 40,
                          child: Tooltip(
                            message:
                                'pages.dashboard.general.move_card.home_z_tooltip'
                                    .tr(),
                            child: ElevatedButton(
                                onPressed: model.klippyCanReceiveCommands
                                    ? () => model.onHomeAxisBtn({PrinterAxis.Z})
                                    : null,
                                child: const Icon(Icons.home)),
                          ),
                        ),
                        Container(
                          margin: marginForBtns,
                          height: 40,
                          width: 40,
                          child: ElevatedButton(
                              onPressed: !model.klippyCanReceiveCommands
                                  ? null
                                  : () => model.onMoveBtn(PrinterAxis.Z, false),
                              child: const Icon(FlutterIcons.downsquare_ant)),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: const MoveTable(
                    rowsToShow: [MoveTable.POS_ROW],
                  ),
                ),
                Container(
                  child: Wrap(
                    runSpacing: 4,
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Tooltip(
                        message:
                            'pages.dashboard.general.move_card.home_all_tooltip'
                                .tr(),
                        child: ElevatedButton.icon(
                          onPressed: model.klippyCanReceiveCommands
                              ? () => model.onHomeAxisBtn(
                                  {PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z})
                              : null,
                          icon: const Icon(Icons.home),
                          label: Text(
                              'pages.dashboard.general.move_card.home_all_btn'
                                  .tr()
                                  .toUpperCase()),
                        ),
                      ),
                      if (model.printerData.configFile.hasQuadGantry)
                        Tooltip(
                          message:
                              'pages.dashboard.general.move_card.qgl_tooltip'
                                  .tr(),
                          child: ElevatedButton.icon(
                            onPressed: !model.klippyCanReceiveCommands
                                ? null
                                : model.onQuadGantry,
                            icon: const Icon(FlutterIcons.quadcopter_mco),
                            label: Text(
                                'pages.dashboard.general.move_card.qgl_btn'
                                    .tr()
                                    .toUpperCase()),
                          ),
                        ),
                      if (model.printerData.configFile.hasBedMesh)
                        Tooltip(
                          message:
                              'pages.dashboard.general.move_card.mesh_tooltip'
                                  .tr(),
                          child: ElevatedButton.icon(
                            onPressed: !model.klippyCanReceiveCommands
                                ? null
                                : model.onBedMesh,
                            icon: const Icon(FlutterIcons.map_marker_path_mco),
                            label: Text(
                                'pages.dashboard.general.move_card.mesh_btn'
                                    .tr()
                                    .toUpperCase()),
                            // color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      Tooltip(
                        message: 'pages.dashboard.general.move_card.m84_tooltip'
                            .tr(),
                        child: ElevatedButton.icon(
                          onPressed: !model.klippyCanReceiveCommands
                              ? null
                              : model.onMotorOff,
                          icon: const Icon(Icons.near_me_disabled),
                          label:
                              Text('pages.dashboard.general.move_card.m84_btn')
                                  .tr(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                        '${'pages.dashboard.general.move_card.step_size'.tr()} [mm]'),
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
        color: Theme.of(context).chipTheme.deleteIconColor,
        size: 20,
      ),
      label: Text(_homedChipTitle(model.printerData.toolhead.homedAxes)),
      backgroundColor: (model.printerData.toolhead.homedAxes.isNotEmpty)
          ? Colors.lightGreen
          : Colors.orangeAccent,
    );
  }

  String _homedChipTitle(Set<PrinterAxis> homedAxes) {
    if (homedAxes.isEmpty)
      return 'general.none'.tr().toUpperCase();
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
              leading: const Icon(FlutterIcons.align_vertical_middle_ent),
              title: const Text('pages.dashboard.general.baby_step_card.title')
                  .tr(),
              trailing: Chip(
                avatar: Icon(
                  FlutterIcons.progress_wrench_mco,
                  color: Theme.of(context).iconTheme.color,
                  size: 20,
                ),
                label:
                    Text('${model.printerData.zOffset.toStringAsFixed(3)}mm'),
                // ViewModelBuilder.reactive(
                //     builder: (context, model, child) => Text('0.000 mm'),
                //     viewModelBuilder: () => model),
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: ElevatedButton(
                          onPressed: model.klippyCanReceiveCommands
                              ? () => model.onBabyStepping()
                              : null,
                          child: const Icon(FlutterIcons.upsquare_ant)),
                      height: 40,
                      width: 40,
                    ),
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: ElevatedButton(
                          onPressed: model.klippyCanReceiveCommands
                              ? () => model.onBabyStepping(false)
                              : null,
                          child: const Icon(FlutterIcons.downsquare_ant)),
                      height: 40,
                      width: 40,
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          '${'pages.dashboard.general.move_card.step_size'.tr()} [mm]'),
                    ),
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
}

class MoveTable extends ViewModelWidget<GeneralTabViewModel> {
  static const String POS_ROW = "p";
  static const String MOV_ROW = "m";

  final List<String> rowsToShow;

  const MoveTable({Key? key, this.rowsToShow = const [POS_ROW, MOV_ROW]})
      : super(key: key);

  @override
  Widget build(BuildContext context, GeneralTabViewModel model) {
    return Table(
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
        if (rowsToShow.contains(POS_ROW))
          TableRow(children: [
            const Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Icon(FlutterIcons.axis_arrow_mco),
            ),
            Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('X'),
                    Text(
                        '${model.printerData.toolhead.position[0].toStringAsFixed(2)}'),
                  ],
                )),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Y'),
                  Text(
                      '${model.printerData.toolhead.position[1].toStringAsFixed(2)}'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Z'),
                  Text(
                      '${model.printerData.toolhead.position[2].toStringAsFixed(2)}'),
                ],
              ),
            ),
          ]),
        if (rowsToShow.contains(MOV_ROW) && model.isPrintingOrPaused)
          TableRow(
            children: [
              const Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Icon(FlutterIcons.printer_3d_mco),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('pages.dashboard.general.print_card.speed').tr(),
                    Text('${model.printerData.gCodeMove.mmSpeed} mm/s'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('pages.dashboard.general.print_card.layer').tr(),
                    Text('${model.layer}/${model.maxLayers}'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('pages.dashboard.general.print_card.eta').tr(),
                    Text((model.printerData.eta != null)
                        ? DateFormat.Hm().format(model.printerData.eta!)
                        : '--:--'),
                  ],
                ),
              ),
            ],
          )
      ],
    );
  }
}
