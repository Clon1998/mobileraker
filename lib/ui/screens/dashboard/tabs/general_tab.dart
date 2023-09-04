/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/fans/temperature_fan.dart';
import 'package:common/data/dto/machine/heaters/heater_mixin.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/temperature_sensor.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/moonraker_db/temperature_preset.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/IconElevatedButton.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/graph_card_with_button.dart';
import 'package:mobileraker/ui/components/machine_deletion_warning.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/components/supporter_ad.dart';
import 'package:mobileraker/ui/screens/dashboard/components/control_xyz/control_xyz_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/toolhead_info/toolhead_info_table.dart';
import 'package:mobileraker/ui/screens/dashboard/components/webcams/cam_card.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/control_tab.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/general_tab_controller.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stringr/stringr.dart';

import '../../../remote_connection_indicator.dart';

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
              var printState = ref.watch(generalTabViewControllerProvider
                  .select((data) => data.value!.printerData.print.state));
              var clientType = ref
                  .watch(generalTabViewControllerProvider.select((data) => data.value!.clientType));

              return PullToRefreshPrinter(
                child: ListView(
                  key: const PageStorageKey('gTab'),
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    const MachineDeletionWarning(),
                    const SupporterAd(),
                    if (clientType != ClientType.local)
                      RemoteConnectionIndicator(
                        clientType: clientType,
                      ),
                    const PrintCard(),
                    const TemperatureCard(),
                    const CamCard(),
                    if (printState != PrintState.printing) const ControlXYZCard(),
                    if (ref
                            .watch(settingServiceProvider)
                            .readBool(AppSettingKeys.alwaysShowBabyStepping) ||
                        const {PrintState.printing, PrintState.paused}.contains(printState))
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
                        onPressed: () => ref.read(dialogServiceProvider).show(DialogRequest(
                            type: CommonDialogs.stacktrace,
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

class PrintCard extends ConsumerWidget {
  const PrintCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    KlipperInstance klippyInstance =
        ref.watch(generalTabViewControllerProvider.select((data) => data.value!.klippyData));

    bool isPrintingOrPaused = ref.watch(generalTabViewControllerProvider.select((data) {
      var printState = data.value!.printerData.print.state;

      return printState == PrintState.printing || printState == PrintState.paused;
    }));

    ExcludeObject? excludeObject = ref.watch(
        generalTabViewControllerProvider.select((data) => data.value!.printerData.excludeObject));

    var themeData = Theme.of(context);
    var klippyCanReceiveCommands = klippyInstance.klippyCanReceiveCommands;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
            leading: Icon(klippyCanReceiveCommands
                ? FlutterIcons.monitor_dashboard_mco
                : FlutterIcons.disconnect_ant),
            title: Text(
                klippyCanReceiveCommands
                    ? ref.watch(generalTabViewControllerProvider
                        .select((data) => data.value!.printerData.print.stateName))
                    : klippyInstance.klippyStateMessage ??
                        'Klipper: ${tr(klippyInstance.klippyState.name)}',
                style: TextStyle(
                    color: !klippyCanReceiveCommands ? themeData.colorScheme.error : null)),
            subtitle: _subTitle(ref),
            trailing: _trailing(context, ref, themeData, klippyCanReceiveCommands),
          ),
          if (const {KlipperState.shutdown, KlipperState.error}
              .contains(klippyInstance.klippyState))
            ElevatedButtonTheme(
              data: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: themeData.colorScheme.error,
                      foregroundColor: themeData.colorScheme.onError)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed:
                        ref.read(generalTabViewControllerProvider.notifier).onRestartKlipperPressed,
                    child: const Text('pages.dashboard.general.restart_klipper').tr(),
                  ),
                  ElevatedButton(
                    onPressed:
                        ref.read(generalTabViewControllerProvider.notifier).onRestartMCUPressed,
                    child: const Text('pages.dashboard.general.restart_mcu').tr(),
                  )
                ],
              ),
            ),
          const M117Message(),
          if (klippyCanReceiveCommands &&
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
                    onPressed:
                        ref.read(generalTabViewControllerProvider.notifier).onExcludeObjectPressed,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('pages.dashboard.general.print_card.current_object').tr(),
                        Text(
                          excludeObject.currentObject ?? 'general.none'.tr(),
                          style: themeData.textTheme.bodyMedium
                              ?.copyWith(color: themeData.textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (klippyCanReceiveCommands && isPrintingOrPaused) ...[
            const Divider(
              thickness: 1,
              height: 0,
            ),
            const ToolheadInfoTable()
          ],
        ],
      ),
    );
  }

  Widget? _trailing(
      BuildContext context, WidgetRef ref, ThemeData themeData, bool klippyCanReceiveCommands) {
    PrintState printState = ref.watch(
        generalTabViewControllerProvider.select((data) => data.value!.printerData.print.state));

    var progress = ref.watch(
        generalTabViewControllerProvider.select((data) => data.value!.printerData.printProgress));

    switch (printState) {
      case PrintState.printing:
        return CircularPercentIndicator(
          radius: 25,
          lineWidth: 4,
          percent: progress,
          center: Text(NumberFormat.percentPattern(context.locale.languageCode).format(progress)),
          progressColor: (printState == PrintState.complete) ? Colors.green : Colors.deepOrange,
        );
      case PrintState.complete:
      case PrintState.cancelled:
        return PopupMenuButton(
          enabled: klippyCanReceiveCommands,
          padding: EdgeInsets.zero,
          position: PopupMenuPosition.over,
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              enabled: klippyCanReceiveCommands,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onTap: ref.read(generalTabViewControllerProvider.notifier).onResetPrintTap,
              child: Row(
                children: [
                  Icon(
                    Icons.restart_alt_outlined,
                    color: themeData.colorScheme.primary,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text('pages.dashboard.general.print_card.reset',
                      style: TextStyle(color: themeData.colorScheme.primary))
                      .tr()
                ],
              ),
            ),
            PopupMenuItem(
              enabled: klippyCanReceiveCommands,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onTap: ref.read(generalTabViewControllerProvider.notifier).onReprintTap,
              child: Row(
                children: [
                  Icon(
                    FlutterIcons.printer_3d_nozzle_mco,
                    color: themeData.colorScheme.primary,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    'pages.dashboard.general.print_card.reprint',
                    style: TextStyle(color: themeData.colorScheme.primary),
                  ).tr()
                ],
              ),
            )
          ],
          child: TextButton.icon(
              style: klippyCanReceiveCommands
                  ? TextButton.styleFrom(disabledForegroundColor: themeData.colorScheme.primary)
                  : null,
              onPressed: null,
              icon: const Icon(Icons.more_vert),
              label: const Text('pages.dashboard.general.move_card.more_btn').tr()),
        );
      default:
        return null;
    }
  }

  Widget? _subTitle(WidgetRef ref) {
    var print =
        ref.watch(generalTabViewControllerProvider.select((data) => data.value!.printerData.print));

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
  const _TemperatureCardTitle({Key? key, required this.title}) : super(key: key);

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
        onPressed: ref.read(generalTabViewControllerProvider.notifier).flipTemperatureCard,
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
                  title: const Text('pages.dashboard.general.temp_card.temp_presets').tr()),
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
                title: const Text('pages.dashboard.general.temp_card.title').tr()),
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

    int extruderCnt = ref.watch(
        generalTabViewControllerProvider.select((data) => data.value!.printerData.extruderCount));

    int genericHeateCnt = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) =>
            value.printerData.genericHeaters.values.where((e) => !e.name.startsWith('_')).length))
        .valueOrNull!;

    int sensorsCnt = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value
            .printerData.temperatureSensors.values
            .where((e) => !e.name.startsWith('_'))
            .length))
        .valueOrNull!;

    int temperatureFanCnt = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value
            .printerData.fans.values
            .where((e) => !e.name.startsWith('_'))
            .whereType<TemperatureFan>()
            .length))
        .valueOrNull!;

    return AdaptiveHorizontalScroll(
      pageStorageKey: "temps",
      children: [
        ...List.generate(
            extruderCnt,
            (index) => _HeaterMixinCard(
                heaterProvider: machinePrinterKlippySettingsProvider
                    .selectAs((value) => value.printerData.extruders[index]))),
        if (hasHeaterBed)
          _HeaterMixinCard(
            heaterProvider: machinePrinterKlippySettingsProvider
                .selectAs((data) => data.printerData.heaterBed!),
          ),
        ...List.generate(
            genericHeateCnt,
            (index) => _HeaterMixinCard(
                heaterProvider: machinePrinterKlippySettingsProvider.selectAs((value) => value
                    .printerData.genericHeaters.values
                    .where((element) => !element.name.startsWith('_'))
                    .elementAt(index)))),
        ...List.generate(
            sensorsCnt,
            (index) => _SensorCard(
                sensorProvider: machinePrinterKlippySettingsProvider.selectAs((value) => value
                    .printerData.temperatureSensors.values
                    .where((element) => !element.name.startsWith('_'))
                    .elementAt(index)))),
        ...List.generate(
            temperatureFanCnt,
            (index) => _TemperatureFanCard(
                tempFanProvider: machinePrinterKlippySettingsProvider.selectAs((value) => value
                    .printerData.fans.values
                    .where((element) => !element.name.startsWith('_'))
                    .whereType<TemperatureFan>()
                    .elementAt(index)))),
      ],
    );
  }
}

class _HeaterMixinCard extends HookConsumerWidget {
  const _HeaterMixinCard({Key? key, required this.heaterProvider}) : super(key: key);
  final ProviderListenable<AsyncValue<HeaterMixin>> heaterProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var genericHeater = ref.watch(heaterProvider).valueOrNull;

    if (genericHeater == null) return const SizedBox.shrink();

    var spots = useState(<FlSpot>[]);

    var temperatureHistory = genericHeater.temperatureHistory;
    if (temperatureHistory != null) {
      List<double> sublist = temperatureHistory.sublist(max(0, temperatureHistory.length - 300));
      spots.value.clear();
      spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    }

    return _HeaterCard(
      name: beautifyName(genericHeater.name),
      current: genericHeater.temperature,
      target: genericHeater.target,
      spots: spots.value,
      onTap: ref.watch(generalTabViewControllerProvider
              .select((data) => data.value!.klippyData.klippyCanReceiveCommands))
          ? () => ref.read(generalTabViewControllerProvider.notifier).editHHHeater(genericHeater)
          : null,
    );
  }
}

class _SensorCard extends HookConsumerWidget {
  const _SensorCard({Key? key, required this.sensorProvider}) : super(key: key);
  final ProviderListenable<AsyncValue<TemperatureSensor>> sensorProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TemperatureSensor temperatureSensor = ref.watch(sensorProvider).valueOrNull!;

    var spots = useState(<FlSpot>[]);
    var temperatureHistory = temperatureSensor.temperatureHistory;

    if (temperatureHistory != null) {
      List<double> sublist = temperatureHistory.sublist(max(0, temperatureHistory.length - 300));
      spots.value.clear();
      spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    }
    var beautifiedNamed = beautifyName(temperatureSensor.name);

    return GraphCardWithButton(
      plotSpots: spots.value,
      buttonChild: const Text('pages.dashboard.general.temp_card.btn_thermistor').tr(),
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
    NumberFormat numberFormat = NumberFormat('0.0', context.locale.languageCode);
    ThemeData themeData = Theme.of(context);
    Color colorBg = themeData.colorScheme.surfaceVariant;
    if (target > 0 && onTap != null) {
      colorBg = Color.alphaBlend(
          const Color.fromRGBO(178, 24, 24, 1).withOpacity(min(current / target, 1)), colorBg);
    } else if (current > _stillHotTemp) {
      colorBg = Color.alphaBlend(
          const Color.fromRGBO(243, 106, 65, 1.0).withOpacity(min(current / _stillHotTemp - 1, 1)),
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
                    Text('${numberFormat.format(current)} °C',
                        style: innerTheme.textTheme.titleLarge),
                    Text(target > 0
                        ? 'pages.dashboard.general.temp_card.heater_on'
                            .tr(args: [numberFormat.format(target)])
                        : 'general.off'.tr()),
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
  const _TemperatureFanCard({Key? key, required this.tempFanProvider}) : super(key: key);
  final ProviderListenable<AsyncValue<TemperatureFan>> tempFanProvider;
  static const double icoSize = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TemperatureFan temperatureFan = ref.watch(tempFanProvider).valueOrNull!;

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
      onTap: ref.watch(generalTabViewControllerProvider
              .select((data) => data.value!.klippyData.klippyCanReceiveCommands))
          ? () =>
              ref.read(generalTabViewControllerProvider.notifier).editTemperatureFan(temperatureFan)
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

    List<TemperaturePreset> tempPresets = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value?.settings.temperaturePresets ?? const []));
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

//
class _BabySteppingCard extends ConsumerWidget {
  const _BabySteppingCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var zOffset = ref.watch(printerSelectedProvider.select((data) => data.value!.zOffset));
    var klippyCanReceiveCommands = ref
        .watch(generalTabViewControllerProvider
            .selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
              leading: const Icon(FlutterIcons.align_vertical_middle_ent),
              title: const Text('pages.dashboard.general.baby_step_card.title').tr(),
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Column(
                  children: [
                    SquareElevatedIconButton(
                        margin: const EdgeInsets.all(10),
                        onPressed: klippyCanReceiveCommands
                            ? () => ref.read(babyStepControllerProvider.notifier).onBabyStepping()
                            : null,
                        child: const Icon(FlutterIcons.upsquare_ant)),
                    SquareElevatedIconButton(
                        margin: const EdgeInsets.all(10),
                        onPressed: klippyCanReceiveCommands
                            ? () =>
                                ref.read(babyStepControllerProvider.notifier).onBabyStepping(false)
                            : null,
                        child: const Icon(FlutterIcons.downsquare_ant)),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${'pages.dashboard.general.move_card.step_size'.tr()} [mm]'),
                    ),
                    RangeSelector(
                        selectedIndex: ref.watch(babyStepControllerProvider),
                        onSelected: ref
                            .read(babyStepControllerProvider.notifier)
                            .onSelectedBabySteppingSizeChanged,
                        values: ref
                            .read(generalTabViewControllerProvider
                                .select((data) => data.value!.settings.babySteps))
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

class M117Message extends ConsumerWidget {
  const M117Message({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var m117 = ref.watch(generalTabViewControllerProvider
        .selectAs((data) => data.printerData.displayStatus?.message));
    if (m117.valueOrNull == null) return const SizedBox.shrink();

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
                m117.valueOrNull.toString(),
                style: themeData.textTheme.bodySmall,
              ),
            ),
          ),
          IconButton(
            onPressed: ref.read(generalTabViewControllerProvider.notifier).onClearM117,
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
