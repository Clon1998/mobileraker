import 'dart:io';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/machine/exclude_object.dart';
import 'package:mobileraker/data/dto/machine/extruder.dart';
import 'package:mobileraker/data/dto/machine/fans/temperature_fan.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/temperature_sensor.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/dto/machine/virtual_sd_card.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/data/model/hive/webcam_rotation.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';
import 'package:mobileraker/data/model/moonraker_db/temperature_preset.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/graph_card_with_button.dart';
import 'package:mobileraker/ui/components/homed_axis_chip.dart';
import 'package:mobileraker/ui/components/mjpeg.dart';
import 'package:mobileraker/ui/components/octo_widgets.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/control_tab.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/control_xyz_controller.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/general_tab_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:mobileraker/util/time_util.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stringr/stringr.dart';

class GeneralTab extends ConsumerWidget {
  const GeneralTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(generalTabViewControllerProvider.select((value) => value.when(
            data: (data) => const AsyncValue.data(true),
            error: (e, s) => AsyncValue.error(e, s),
            loading: () => const AsyncValue.loading())))
        .when(
            data: (data) {
              var showCams = ref.watch(generalTabViewControllerProvider
                  .select((data) => data.value!.machine.cams.isNotEmpty));
              var printState = ref.watch(generalTabViewControllerProvider
                  .select((data) => data.value!.printerData.print.state));
              var clientType = ref.watch(generalTabViewControllerProvider
                  .select((data) => data.value!.clientType));

              var dismissedRemoteInfo = ref.watch(dismissiedRemoteInfoProvider);

              return PullToRefreshPrinter(
                child: ListView(
                  key: const PageStorageKey('gTab'),
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    if (clientType != ClientType.local) const RemoteIndicator(),
                    const PrintCard(),
                    const TemperatureCard(),
                    if (showCams) const CamCard(),
                    if (printState != PrintState.printing)
                      const _ControlXYZCard(),
                    if (ref
                            .watch(settingServiceProvider)
                            .readBool(showBabyAlwaysKey) ||
                        const {PrintState.printing, PrintState.paused}
                            .contains(printState))
                      const _BabySteppingCard(),
                  ],
                ),
              );
            },
            error: (e, s) {
              logger.e('Cought error in General tab', e, s);
              return Center(
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
                        onPressed: () => ref.read(dialogServiceProvider).show(
                            DialogRequest(
                                type: DialogType.stacktrace,
                                title: e.runtimeType.toString(),
                                body: 'Exception:\n $e\n\n$s')),
                        child: const Text('Show Error'))
                  ],
                ),
              );
            },
            loading: () => const _FetchingData());
  }
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
        ],
      ),
    );
  }
}

class RemoteIndicator extends ConsumerWidget {
  const RemoteIndicator({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSwitcher(
        duration: kThemeAnimationDuration,
        switchInCurve: Curves.easeInCubic,
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              child: FadeTransition(
                opacity: anim,
                child: child,
              ),
            ),
        child: (ref.watch(dismissiedRemoteInfoProvider))
            ? const SizedBox.shrink()
            : Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding:
                          const EdgeInsets.only(top: 3, left: 16, right: 16),
                      leading: const OctoIndicator(),
                      title: Text('Using remote connection!'),
                      trailing: IconButton(
                          onPressed: () => ref
                              .read(dismissiedRemoteInfoProvider.notifier)
                              .state = true,
                          icon: const Icon(Icons.close)),
                    ),
                  ],
                ),
              ));
  }
}

class PrintCard extends ConsumerWidget {
  const PrintCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    KlipperInstance klippyInstance = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.klippyData));

    bool isPrintingOrPaused =
        ref.watch(generalTabViewControllerProvider.select((data) {
      var printState = data.value!.printerData.print.state;

      return printState == PrintState.printing ||
          printState == PrintState.paused;
    }));

    ExcludeObject? excludeObject = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.printerData.excludeObject));

    var themeData = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
            leading: Icon(klippyInstance.klippyCanReceiveCommands
                ? FlutterIcons.monitor_dashboard_mco
                : FlutterIcons.disconnect_ant),
            title: Text(
                klippyInstance.klippyCanReceiveCommands
                    ? ref.watch(generalTabViewControllerProvider.select(
                        (data) => data.value!.printerData.print.stateName))
                    : klippyInstance.klippyStateMessage ??
                        'Klipper: ${klippyInstance.klippyState.name}',
                style: TextStyle(
                    color: !klippyInstance.klippyCanReceiveCommands
                        ? themeData.colorScheme.error
                        : null)),
            subtitle: _subTitle(ref),
            trailing: _trailing(ref),
          ),
          if (const {KlipperState.shutdown, KlipperState.error}
              .contains(klippyInstance.klippyState))
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: ref
                      .read(generalTabViewControllerProvider.notifier)
                      .onRestartKlipperPressed,
                  child: const Text('pages.dashboard.general.restart_klipper')
                      .tr(),
                ),
                ElevatedButton(
                  onPressed: ref
                      .read(generalTabViewControllerProvider.notifier)
                      .onRestartMCUPressed,
                  child: const Text('pages.dashboard.general.restart_mcu').tr(),
                )
              ],
            ),
          const M117Message(),
          if (klippyInstance.klippyCanReceiveCommands &&
              isPrintingOrPaused &&
              excludeObject != null &&
              excludeObject.available) ...[
            const Divider(
              thickness: 1,
              height: 0,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
              child: Row(
                children: [
                  IconButton(
                    color: themeData.colorScheme.primary,
                    icon: const Icon(FlutterIcons.object_group_faw5),
                    tooltip: 'dialogs.exclude_object.title'.tr(),
                    onPressed: ref
                        .read(generalTabViewControllerProvider.notifier)
                        .onExcludeObjectPressed,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                                'pages.dashboard.general.print_card.current_object')
                            .tr(),
                        Text(
                          excludeObject.currentObject ?? 'general.none'.tr(),
                          style: themeData.textTheme.bodyMedium?.copyWith(
                              color: themeData.textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (klippyInstance.klippyCanReceiveCommands &&
              isPrintingOrPaused) ...[
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

  Widget? _trailing(WidgetRef ref) {
    PrintState printState = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.printerData.print.state));

    VirtualSdCard virtualSdCard = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.printerData.virtualSdCard));

    switch (printState) {
      case PrintState.printing:
        return CircularPercentIndicator(
          radius: 25,
          lineWidth: 4,
          percent: virtualSdCard.progress,
          center: Text('${(virtualSdCard.progress * 100).round()}%'),
          progressColor: (printState == PrintState.complete)
              ? Colors.green
              : Colors.deepOrange,
        );
      case PrintState.complete:
        return TextButton.icon(
            onPressed: ref
                .read(generalTabViewControllerProvider.notifier)
                .onResetPrintTap,
            icon: const Icon(Icons.restart_alt_outlined),
            label: const Text('pages.dashboard.general.print_card.reset').tr());
      default:
        return null;
    }
  }

  Widget? _subTitle(WidgetRef ref) {
    var print = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.printerData.print));

    switch (print.state) {
      case PrintState.paused:
      case PrintState.printing:
        return Text(print.filename);
      case PrintState.error:
        return Text(print.message);
      default:
        return null;
    }
  }
}

class CamCard extends ConsumerWidget {
  const CamCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double minWebCamHeight = 280;
    var machine = ref.watch(generalTabViewControllerProvider
        .select((value) => value.value!.machine));
    WebcamSetting selectedCam = ref.watch(camCardControllerProvider);
    var clientType = ref.watch(generalTabViewControllerProvider
        .select((value) => value.value!.clientType));

    Uri camUri = Uri.parse(selectedCam.url);
    Map<String, String> headers = {};
    if (clientType == ClientType.octo) {
      Uri machineUri = Uri.parse(machine.wsUrl);
      if (machineUri.host == camUri.host) {
        var octoEverywhere = machine.octoEverywhere!;
        camUri = camUri.replace(scheme: 'https', host: octoEverywhere.uri.host);

        headers[HttpHeaders.authorizationHeader] =
            octoEverywhere.basicAuthorizationHeader;
      }
    }
    var webcams = machine.cams;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              FlutterIcons.webcam_mco,
            ),
            title: const Text('pages.dashboard.general.cam_card.webcam').tr(),
            trailing: (webcams.length > 1)
                ? DropdownButton(
                    value: selectedCam,
                    onChanged: ref
                        .read(camCardControllerProvider.notifier)
                        .onSelectedChange,
                    items: webcams.map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(e.name),
                      );
                    }).toList())
                : null,
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            constraints: const BoxConstraints(minHeight: minWebCamHeight),
            child: Center(
                child: Mjpeg(
              key: ValueKey(selectedCam),
              imageBuilder: _imageBuilder,
              config: MjpegConfig(
                  feedUri: camUri.toString(),
                  targetFps: selectedCam.targetFps,
                  mode: selectedCam.mode,
                  httpHeader: headers),
              landscape: selectedCam.rotate == WebCamRotation.landscape,
              transform: selectedCam.transformMatrix,
              showFps: true,
              stackChild: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.aspect_ratio),
                      tooltip:
                          'pages.dashboard.general.cam_card.fullscreen'.tr(),
                      onPressed: ref
                          .read(camCardControllerProvider.notifier)
                          .onFullScreenTap,
                    ),
                  ),
                ),
                if (clientType != ClientType.local)
                  const Positioned.fill(
                      child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: OctoIndicator(),
                    ),
                  )),
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

class TemperatureCard extends ConsumerWidget {
  const TemperatureCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FlipCard(
      controller: ref.watch(flipCardControllerProvider),
      flipOnTouch: false,
      direction: FlipDirection.VERTICAL,
      // back: const Text('front'),
      front: const _Heaters(),
      back: const _Presets(),
    );
  }
}

class _TemperatureCardTitle extends ConsumerWidget {
  const _TemperatureCardTitle({Key? key, required this.title})
      : super(key: key);

  final Widget? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(
        FlutterIcons.fire_alt_faw5s,
        color: ref.watch(generalTabViewControllerProvider.select((data) =>
                data.value!.printerData.extruder.target +
                    (data.value!.printerData.heaterBed?.target ?? 0) >
                0))
            ? Colors.deepOrange
            : null,
      ),
      title: title,
      trailing: TextButton(
        onPressed: ref
            .read(generalTabViewControllerProvider.notifier)
            .flipTemperatureCard,
        child: const Text('pages.dashboard.general.temp_card.presets_btn').tr(),
      ),
    );
  }
}

class _Presets extends ConsumerWidget {
  const _Presets({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            children: [
              _TemperatureCardTitle(
                  title: const Text(
                          'pages.dashboard.general.temp_card.temp_presets')
                      .tr()),
              const _TemperaturePresetsHorizontalScroll()
            ],
          ),
        ),
      );
}

class _Heaters extends ConsumerWidget {
  const _Heaters({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          children: [
            _TemperatureCardTitle(
                title:
                    const Text('pages.dashboard.general.temp_card.title').tr()),
            const _HeatersHorizontalScroll(),
          ],
        ),
      ),
    );
  }
}

class _HeatersHorizontalScroll extends ConsumerWidget {
  const _HeatersHorizontalScroll({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool hasHeaterBed = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.printerData.heaterBed != null));

    int extruderCnt = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.printerData.extruderCount));

    int sensorsCnt = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value
            .printerData.temperatureSensors.values
            .where((e) => !e.name.startsWith('_'))
            .length))
        .valueOrFullNull!;

    int temperatureFanCnt = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value
            .printerData.fans.values
            .where((e) => !e.name.startsWith('_'))
            .whereType<TemperatureFan>()
            .length))
        .valueOrFullNull!;

    return AdaptiveHorizontalScroll(
      pageStorageKey: "temps",
      children: [
        ...List.generate(extruderCnt, (index) => _ExtruderCard(extNum: index)),
        if (hasHeaterBed) const _HeatedBedCard(),
        ...List.generate(
            sensorsCnt,
            (index) => _SensorCard(
                sensorProvider: machinePrinterKlippySettingsProvider.selectAs(
                    (value) => value.printerData.temperatureSensors.values
                        .where((element) => !element.name.startsWith('_'))
                        .elementAt(index)))),
        ...List.generate(
            temperatureFanCnt,
            (index) => _TemperatureFanCard(
                tempFanProvider: machinePrinterKlippySettingsProvider.selectAs(
                    (value) => value.printerData.fans.values
                        .where((element) => !element.name.startsWith('_'))
                        .whereType<TemperatureFan>()
                        .elementAt(index)))),
      ],
    );
  }
}

class _ExtruderCard extends HookConsumerWidget {
  const _ExtruderCard({Key? key, required this.extNum}) : super(key: key);
  final int extNum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Extruder extruder = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.printerData.extruders[extNum]));
    var spots = useState(<FlSpot>[]);

    var temperatureHistory = extruder.temperatureHistory;
    if (temperatureHistory != null) {
      List<double> sublist =
          temperatureHistory.sublist(max(0, temperatureHistory.length - 300));

      spots.value.clear();
      spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    }
    final String extruderNameStr =
        tr('pages.dashboard.control.extrude_card.title');

    return _HeaterCard(
      name: extNum > 0 ? '$extruderNameStr $extNum' : extruderNameStr,
      current: extruder.temperature,
      target: extruder.target,
      spots: spots.value,
      // spots: model.heatedBedKeeper.spots,
      onTap: ref.watch(generalTabViewControllerProvider.select(
              (data) => data.value!.klippyData.klippyCanReceiveCommands))
          ? () => ref
              .read(generalTabViewControllerProvider.notifier)
              .editExtruderHeater(extruder)
          : null,
    );
  }
}

class _HeatedBedCard extends HookConsumerWidget {
  const _HeatedBedCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var heaterBed = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.printerData.heaterBed));

    if (heaterBed == null) {
      logger.w('Tried to build a _HeatedBedCard while heater bed is null!');
      return const SizedBox.shrink();
    }

    var spots = useState(<FlSpot>[]);

    var temperatureHistory = heaterBed.temperatureHistory;
    if (temperatureHistory != null) {
      List<double> sublist =
          temperatureHistory.sublist(max(0, temperatureHistory.length - 300));
      spots.value.clear();
      spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    }

    return _HeaterCard(
      name: 'pages.dashboard.general.temp_card.bed'.tr(),
      current: heaterBed.temperature,
      target: heaterBed.target,
      spots: spots.value,
      onTap: ref.watch(generalTabViewControllerProvider.select(
              (data) => data.value!.klippyData.klippyCanReceiveCommands))
          ? ref.read(generalTabViewControllerProvider.notifier).editHeatedBed
          : null,
    );
  }
}

class _SensorCard extends HookConsumerWidget {
  const _SensorCard({Key? key, required this.sensorProvider}) : super(key: key);
  final ProviderListenable<AsyncValue<TemperatureSensor>> sensorProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TemperatureSensor temperatureSensor =
        ref.watch(sensorProvider).valueOrFullNull!;

    var spots = useState(<FlSpot>[]);
    var temperatureHistory = temperatureSensor.temperatureHistory;

    if (temperatureHistory != null) {
      List<double> sublist =
          temperatureHistory.sublist(max(0, temperatureHistory.length - 300));
      spots.value.clear();
      spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    }
    var beautifiedNamed = beautifyName(temperatureSensor.name);

    return GraphCardWithButton(
      plotSpots: spots.value,
      buttonChild:
          const Text('pages.dashboard.general.temp_card.btn_thermistor').tr(),
      onTap: null,
      builder: (context) => Tooltip(
        message: beautifiedNamed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              beautifiedNamed,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text('${temperatureSensor.temperature.toStringAsFixed(1)} °C',
                style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${temperatureSensor.measuredMaxTemp.toStringAsFixed(1)} °C max',
            ),
          ],
        ),
      ),
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
          const Color.fromRGBO(178, 24, 24, 1)
              .withOpacity(min(current / target, 1)),
          colorBg);
    } else if (current > _stillHotTemp) {
      colorBg = Color.alphaBlend(
          const Color.fromRGBO(243, 106, 65, 1.0)
              .withOpacity(min(current / _stillHotTemp - 1, 1)),
          colorBg);
    }

    return GraphCardWithButton(
        backgroundColor: colorBg,
        plotSpots: spots,
        buttonChild: const Text('general.set').tr(),
        onTap: onTap,
        builder: (BuildContext context) {
          var innerTheme = Theme.of(context);
          return Tooltip(
            message: name,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: innerTheme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('${current.toStringAsFixed(1)} °C',
                        style: innerTheme.textTheme.titleLarge),
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
          );
        });
  }
}

class _TemperatureFanCard extends HookConsumerWidget {
  const _TemperatureFanCard({Key? key, required this.tempFanProvider})
      : super(key: key);
  final ProviderListenable<AsyncValue<TemperatureFan>> tempFanProvider;
  static const double icoSize = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TemperatureFan temperatureFan = ref.watch(tempFanProvider).valueOrFullNull!;

    // var spots = useState(<FlSpot>[]);
    // var temperatureHistory = temperatureSensor.temperatureHistory;
    //
    // if (temperatureHistory != null) {
    //   List<double> sublist =
    //   temperatureHistory.sublist(max(0, temperatureHistory.length - 300));
    //   spots.value.clear();
    //   spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    // }
    var beautifiedNamed = beautifyName(temperatureFan.name);

    return CardWithButton(
      buttonChild: const Text('general.set').tr(),
      onTap: ref.watch(generalTabViewControllerProvider.select(
              (data) => data.value!.klippyData.klippyCanReceiveCommands))
          ? () => ref
              .read(generalTabViewControllerProvider.notifier)
              .editTemperatureFan(temperatureFan)
          : null,
      builder: (context) => Tooltip(
        message: beautifiedNamed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beautifiedNamed,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${temperatureFan.temperature.toStringAsFixed(1)} °C',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                  'pages.dashboard.general.temp_card.heater_on'
                      .tr(args: [temperatureFan.target.toStringAsFixed(1)]),
                ),
              ],
            ),
            temperatureFan.speed > 0
                ? const SpinningFan(size: icoSize)
                : const Icon(
                    FlutterIcons.fan_off_mco,
                    size: icoSize,
                  ),
          ],
        ),
      ),
    );
  }
}

class _TemperaturePresetsHorizontalScroll extends ConsumerWidget {
  const _TemperaturePresetsHorizontalScroll({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyCanReceiveCommand = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.klippyData.klippyCanReceiveCommands));
    var hasPrintBed = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.printerData.heaterBed != null));

    var coolOf = _TemperaturePresetCard(
      presetName: 'pages.dashboard.general.temp_preset_card.cooloff'.tr(),
      extruderTemp: 0,
      bedTemp: hasPrintBed ? 0 : null,
      onTap: klippyCanReceiveCommand
          ? () => ref
              .read(generalTabViewControllerProvider.notifier)
              .adjustNozzleAndBed(0, hasPrintBed ? 0 : null)
          : null,
    );

    List<TemperaturePreset> tempPresets = ref.watch(
        generalTabViewControllerProvider.select(
            (data) => data.value?.settings.temperaturePresets ?? const []));
    var presetWidgets = List.generate(tempPresets.length, (index) {
      TemperaturePreset preset = tempPresets[index];
      return _TemperaturePresetCard(
        presetName: preset.name,
        extruderTemp: preset.extruderTemp,
        bedTemp: hasPrintBed ? preset.bedTemp : null,
        onTap: klippyCanReceiveCommand
            ? () => ref
                .read(generalTabViewControllerProvider.notifier)
                .adjustNozzleAndBed(preset.extruderTemp, preset.bedTemp)
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
  const _TemperaturePresetCard(
      {Key? key,
      required this.presetName,
      required this.extruderTemp,
      required this.bedTemp,
      required this.onTap})
      : super(key: key);

  final String presetName;
  final int extruderTemp;
  final int? bedTemp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CardWithButton(
        buttonChild: const Text('general.set').tr(),
        onTap: onTap,
        builder: (context) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(presetName,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text('pages.dashboard.general.temp_preset_card.h_temp',
                      style: Theme.of(context).textTheme.bodySmall)
                  .tr(args: [extruderTemp.toString()]),
              if (bedTemp != null)
                Text('pages.dashboard.general.temp_preset_card.b_temp',
                        style: Theme.of(context).textTheme.bodySmall)
                    .tr(args: [bedTemp.toString()]),
            ],
          );
        });
  }
}

class _ControlXYZCard extends HookConsumerWidget {
  static const marginForBtns = EdgeInsets.all(10);

  const _ControlXYZCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyCanReceiveCommands = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.klippyData.klippyCanReceiveCommands));
    var iconThemeData = IconTheme.of(context);

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(FlutterIcons.axis_arrow_mco),
            title: const Text('pages.dashboard.general.move_card.title').tr(),
            trailing: const HomedAxisChip(),
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
                                  onPressed: klippyCanReceiveCommands
                                      ? () => ref
                                          .read(controlXYZController.notifier)
                                          .onMoveBtn(PrinterAxis.Y)
                                      : null,
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
                                  onPressed: klippyCanReceiveCommands
                                      ? () => ref
                                          .read(controlXYZController.notifier)
                                          .onMoveBtn(PrinterAxis.X, false)
                                      : null,
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
                                child: _ButtonWithRunningIndicator(
                                    onPressed: klippyCanReceiveCommands &&
                                            ref.watch(
                                                controlXYZController.select(
                                                    (value) => !value.homing))
                                        ? () => ref
                                            .read(controlXYZController.notifier)
                                            .onHomeAxisBtn(
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
                                  onPressed: klippyCanReceiveCommands
                                      ? () => ref
                                          .read(controlXYZController.notifier)
                                          .onMoveBtn(PrinterAxis.X)
                                      : null,
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
                                onPressed: klippyCanReceiveCommands
                                    ? () => ref
                                        .read(controlXYZController.notifier)
                                        .onMoveBtn(PrinterAxis.Y, false)
                                    : null,
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
                              onPressed: klippyCanReceiveCommands
                                  ? () => ref
                                      .read(controlXYZController.notifier)
                                      .onMoveBtn(PrinterAxis.Z)
                                  : null,
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
                            child: _ButtonWithRunningIndicator(
                                onPressed: klippyCanReceiveCommands &&
                                        ref.watch(controlXYZController
                                            .select((value) => !value.homing))
                                    ? () => ref
                                        .read(controlXYZController.notifier)
                                        .onHomeAxisBtn({PrinterAxis.Z})
                                    : null,
                                child: const Icon(Icons.home)),
                          ),
                        ),
                        Container(
                          margin: marginForBtns,
                          height: 40,
                          width: 40,
                          child: ElevatedButton(
                              onPressed: klippyCanReceiveCommands
                                  ? () => ref
                                      .read(controlXYZController.notifier)
                                      .onMoveBtn(PrinterAxis.Z, false)
                                  : null,
                              child: const Icon(FlutterIcons.downsquare_ant)),
                        ),
                      ],
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: MoveTable(
                    rowsToShow: [MoveTable.POS_ROW],
                  ),
                ),
                Wrap(
                  runSpacing: 4,
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Tooltip(
                      message:
                          'pages.dashboard.general.move_card.home_all_tooltip'
                              .tr(),
                      child: _ButtonWithRunningIndicator.icon(
                        onPressed: klippyCanReceiveCommands &&
                                ref.watch(controlXYZController
                                    .select((value) => !value.homing))
                            ? () => ref
                                    .read(controlXYZController.notifier)
                                    .onHomeAxisBtn({
                                  PrinterAxis.X,
                                  PrinterAxis.Y,
                                  PrinterAxis.Z
                                })
                            : null,
                        icon: const Icon(Icons.home),
                        label: Text(
                            'pages.dashboard.general.move_card.home_all_btn'
                                .tr()
                                .toUpperCase()),
                      ),
                    ),
                    if (ref.watch(generalTabViewControllerProvider.select(
                        (data) =>
                            data.valueOrNull?.printerData.configFile
                                .hasQuadGantry ==
                            true)))
                      Tooltip(
                        message: 'pages.dashboard.general.move_card.qgl_tooltip'
                            .tr(),
                        child: _ButtonWithRunningIndicator.icon(
                          onPressed: klippyCanReceiveCommands &&
                                  ref.watch(controlXYZController
                                      .select((value) => !value.qgl))
                              ? ref
                                  .read(controlXYZController.notifier)
                                  .onQuadGantry
                              : null,
                          icon: const Icon(FlutterIcons.quadcopter_mco),
                          label: Text(
                              'pages.dashboard.general.move_card.qgl_btn'
                                  .tr()
                                  .toUpperCase()),
                        ),
                      ),
                    if (ref.watch(generalTabViewControllerProvider.select(
                        (data) =>
                            data.valueOrNull?.printerData.configFile
                                .hasBedMesh ==
                            true)))
                      Tooltip(
                        message:
                            'pages.dashboard.general.move_card.mesh_tooltip'
                                .tr(),
                        child: _ButtonWithRunningIndicator.icon(
                          onPressed: klippyCanReceiveCommands &&
                                  ref.watch(controlXYZController
                                      .select((value) => !value.mesh))
                              ? ref
                                  .read(controlXYZController.notifier)
                                  .onBedMesh
                              : null,
                          icon: const Icon(FlutterIcons.map_marker_path_mco),
                          label: Text(
                              'pages.dashboard.general.move_card.mesh_btn'
                                  .tr()
                                  .toUpperCase()),
                          // color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    if (ref.watch(generalTabViewControllerProvider.select(
                        (data) =>
                            data.valueOrNull?.printerData.configFile
                                .hasScrewTiltAdjust ==
                            true)))
                      Tooltip(
                        message: 'pages.dashboard.general.move_card.stc_tooltip'
                            .tr(),
                        child: ElevatedButton.icon(
                          onPressed: klippyCanReceiveCommands &&
                                  ref.watch(controlXYZController
                                      .select((value) => !value.screwTilt))
                              ? ref
                                  .read(controlXYZController.notifier)
                                  .onScrewTiltCalc
                              : null,
                          icon: const Icon(
                              FlutterIcons.screw_machine_flat_top_mco),
                          label: Text(
                              'pages.dashboard.general.move_card.stc_btn'
                                  .tr()
                                  .toUpperCase()),
                        ),
                      ),
                    if (ref.watch(generalTabViewControllerProvider.select(
                        (data) =>
                            data.valueOrNull?.printerData.configFile.hasZTilt ==
                            true)))
                      Tooltip(
                        message:
                            'pages.dashboard.general.move_card.ztilt_tooltip'
                                .tr(),
                        child: _ButtonWithRunningIndicator.icon(
                          onPressed: klippyCanReceiveCommands &&
                                  ref.watch(controlXYZController
                                      .select((value) => !value.zTilt))
                              ? ref
                                  .read(controlXYZController.notifier)
                                  .onZTiltAdjust
                              : null,
                          icon:
                              const Icon(FlutterIcons.unfold_less_vertical_mco),
                          label: Text(
                              'pages.dashboard.general.move_card.ztilt_btn'
                                  .tr()
                                  .toUpperCase()),
                        ),
                      ),
                    Tooltip(
                      message:
                          'pages.dashboard.general.move_card.m84_tooltip'.tr(),
                      child: _ButtonWithRunningIndicator.icon(
                        onPressed: klippyCanReceiveCommands &&
                                ref.watch(controlXYZController
                                    .select((value) => !value.motorsOff))
                            ? ref.read(controlXYZController.notifier).onMotorOff
                            : null,
                        icon: const Icon(Icons.near_me_disabled),
                        label: const Text(
                                'pages.dashboard.general.move_card.m84_btn')
                            .tr(),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                        '${'pages.dashboard.general.move_card.step_size'.tr()} [mm]'),
                    RangeSelector(
                        selectedIndex: ref.watch(controlXYZController
                            .select((value) => value.index)),
                        onSelected: ref
                            .read(controlXYZController.notifier)
                            .onSelectedAxisStepSizeChanged,
                        values: ref
                            .watch(
                                generalTabViewControllerProvider.select((data) {
                              return data.valueOrNull!.settings.moveSteps;
                            }))
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

//
class _BabySteppingCard extends ConsumerWidget {
  const _BabySteppingCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var zOffset = ref
        .watch(printerSelectedProvider.select((data) => data.value!.zOffset));
    var klippyCanReceiveCommands = ref
        .watch(generalTabViewControllerProvider
            .selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrFullNull!;

    return Card(
      child: Column(
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
                label: Text('${zOffset.toStringAsFixed(3)}mm'),
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
                      height: 40,
                      width: 40,
                      child: ElevatedButton(
                          onPressed: klippyCanReceiveCommands
                              ? () => ref
                                  .read(babyStepControllerProvider.notifier)
                                  .onBabyStepping()
                              : null,
                          child: const Icon(FlutterIcons.upsquare_ant)),
                    ),
                    Container(
                      margin: const EdgeInsets.all(5),
                      height: 40,
                      width: 40,
                      child: ElevatedButton(
                          onPressed: klippyCanReceiveCommands
                              ? () => ref
                                  .read(babyStepControllerProvider.notifier)
                                  .onBabyStepping(false)
                              : null,
                          child: const Icon(FlutterIcons.downsquare_ant)),
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
                        selectedIndex: ref.watch(babyStepControllerProvider),
                        onSelected: ref
                            .read(babyStepControllerProvider.notifier)
                            .onSelectedBabySteppingSizeChanged,
                        values: ref
                            .read(generalTabViewControllerProvider.select(
                                (data) => data.value!.settings.babySteps))
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

class MoveTable extends ConsumerWidget {
  static const String POS_ROW = "p";
  static const String MOV_ROW = "m";

  final List<String> rowsToShow;

  const MoveTable({Key? key, this.rowsToShow = const [POS_ROW, MOV_ROW]})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueWidget(
      // dont ask me why but this.selectAs prevents rebuild on the exact same value...
      value: ref.watch(moveTableStateProvider.selectAs((data) => data)),
      data: (MoveTableState moveTableState) {
        var position =
            ref.watch(settingServiceProvider).readBool(useOffsetPosKey)
                ? moveTableState.postion
                : moveTableState.livePosition;
        return Table(
          border: TableBorder(
              horizontalInside: BorderSide(
                  width: 1,
                  color: Theme.of(context).dividerColor,
                  style: BorderStyle.solid)),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FractionColumnWidth(.1),
          },
          children: [
            if (rowsToShow.contains(POS_ROW))
              TableRow(children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(FlutterIcons.axis_arrow_mco),
                ),
                Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('X'),
                        Text(position[0].toStringAsFixed(2)),
                      ],
                    )),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Y'),
                      Text(position[1].toStringAsFixed(2)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Z'),
                      Text(position[2].toStringAsFixed(2)),
                    ],
                  ),
                ),
              ]),
            if (rowsToShow.contains(MOV_ROW) &&
                moveTableState.printingOrPaused) ...[
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(FlutterIcons.layers_fea),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('pages.dashboard.general.print_card.speed')
                            .tr(),
                        Text('${moveTableState.mmSpeed} mm/s'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('pages.dashboard.general.print_card.layer')
                            .tr(),
                        Text(
                            '${moveTableState.currentLayer}/${moveTableState.maxLayers}'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('pages.dashboard.general.print_card.elapsed')
                            .tr(),
                        Text(secondsToDurationText(
                            moveTableState.totalDuration)),
                      ],
                    ),
                  ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(FlutterIcons.printer_3d_mco),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('pages.dashboard.general.print_card.flow')
                            .tr(),
                        Text('${moveTableState.currentFlow ?? 0} mm³/s'),
                      ],
                    ),
                  ),
                  Tooltip(
                    textAlign: TextAlign.center,
                    message: tr(
                        'pages.dashboard.general.print_card.filament_used',
                        args: [
                          moveTableState.usedFilamentPerc.toStringAsFixed(0),
                          moveTableState.usedFilament?.toStringAsFixed(1) ??
                              '0',
                          moveTableState.totalFilament?.toStringAsFixed(1) ??
                              '-'
                        ]),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                                  'pages.dashboard.general.print_card.filament')
                              .tr(),
                          Text(
                              '${moveTableState.usedFilament?.toStringAsFixed(1) ?? 0} m'),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('pages.dashboard.general.print_card.eta')
                            .tr(),
                        Text((moveTableState.eta != null)
                            ? DateFormat.Hm().format(moveTableState.eta!)
                            : '--:--'),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          ],
        );
      },
    );
  }
}

class M117Message extends ConsumerWidget {
  const M117Message({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var m117 = ref.watch(generalTabViewControllerProvider
        .selectAs((data) => data.printerData.displayStatus.message));
    if (m117.valueOrFullNull == null) return const SizedBox.shrink();

    var themeData = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'M117',
            style: themeData.textTheme.titleSmall,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                m117.valueOrFullNull.toString(),
                style: themeData.textTheme.bodySmall,
              ),
            ),
          ),
          IconButton(
            onPressed:
                ref.read(generalTabViewControllerProvider.notifier).onClearM117,
            icon: const Icon(Icons.clear),
            iconSize: 16,
            color: themeData.colorScheme.primary,
            tooltip: "Clear M117",
          )
        ],
      ),
    );
  }
}

class _ButtonWithRunningIndicator extends HookConsumerWidget {
  const _ButtonWithRunningIndicator({
    Key? key,
    required this.child,
    required this.onPressed,
  })  : label = null,
        super(key: key);

  const _ButtonWithRunningIndicator.icon({
    Key? key,
    required Icon icon,
    required this.label,
    required this.onPressed,
  })  : child = icon,
        super(key: key);

  final Icon child;
  final Widget? label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var animCtrler = useAnimationController(
        duration: const Duration(seconds: 1),
        lowerBound: 0.5,
        upperBound: 1,
        initialValue: 1);
    if (onPressed == null) {
      animCtrler.repeat(reverse: true);
    } else {
      animCtrler.stop();
    }

    Widget ico;

    if (onPressed == null) {
      ico = ScaleTransition(
        scale: CurvedAnimation(parent: animCtrler, curve: Curves.elasticInOut),
        child: child,
      );
    } else {
      ico = child;
    }

    if (label == null) {
      return ElevatedButton(
        onPressed: onPressed,
        child: ico,
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: ico,
      label: label!,
    );
  }
}
