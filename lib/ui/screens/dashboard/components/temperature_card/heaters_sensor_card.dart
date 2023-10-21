/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/config/fan/config_temperature_fan.dart';
import 'package:common/data/dto/machine/fans/temperature_fan.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/heaters/generic_heater.dart';
import 'package:common/data/dto/machine/heaters/heater_bed.dart';
import 'package:common/data/dto/machine/heaters/heater_mixin.dart';
import 'package:common/data/dto/machine/temperature_sensor.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stringr/stringr.dart';

import '../../../../../service/ui/dialog_service_impl.dart';
import '../../../../components/adaptive_horizontal_scroll.dart';
import '../../../../components/card_with_button.dart';
import '../../../../components/dialog/edit_form/num_edit_form_controller.dart';
import '../../../../components/graph_card_with_button.dart';
import '../../tabs/control_tab.dart';
import 'temperature_sensor_preset_card.dart';

part 'heaters_sensor_card.freezed.dart';
part 'heaters_sensor_card.g.dart';

class HeaterSensorCard extends ConsumerWidget {
  const HeaterSensorCard({Key? key, required this.machineUUID, this.trailing}) : super(key: key);

  final String machineUUID;

  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var showLoading =
        ref.watch(_controllerProvider(machineUUID).select((value) => value.isLoading && !value.isReloading));
    if (showLoading) {
      return const HeaterSensorPresetCardLoading();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          children: [
            HeaterSensorPresetCardTitle(
                machineUUID: machineUUID,
                title: const Text('pages.dashboard.general.temp_card.title').tr(),
                trailing: trailing),
            _CardBody(
              machineUUID: machineUUID,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({
    Key? key,
    required this.machineUUID,
  }) : super(key: key);

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ROHE model nutzung ist AA. Wenn eine der listen sich ändert wird alles neu gebaut! Lieber einzelne Selects darauf!
    var provider = _controllerProvider(machineUUID);

    var hasPrintBed = ref.watch(provider.selectAs((value) => value.hasPrintBed)).value!;
    var extruderCount = ref.watch(provider.selectAs((value) => value.extruders.length)).value!;
    var genericHeatersCount = ref.watch(provider.selectAs((value) => value.genericHeaters.length)).value!;
    var temperatureSensorCount = ref.watch(provider.selectAs((value) => value.temperatureSensors.length)).value!;
    var temperatureFanCount = ref.watch(provider.selectAs((value) => value.temperatureFans.length)).value!;

    return AdaptiveHorizontalScroll(
      pageStorageKey: "temps",
      children: [
        ..._extruderTiles(extruderCount),
        if (hasPrintBed)
          _HeaterMixinTile(
              machineUUID: machineUUID, heaterProvider: provider.select((value) => value.value!.heaterBed!)),
        ..._genericHeaterTiles(genericHeatersCount),
        ..._temperatureSensorTiles(temperatureSensorCount),
        ..._temperatureFanTiles(temperatureFanCount),
      ],
    );
  }

  List<Widget> _extruderTiles(int count) {
    return List.generate(
        count,
        (index) => _HeaterMixinTile(
            machineUUID: machineUUID,
            heaterProvider: _controllerProvider(machineUUID).select((value) => value.value!.extruders[index])));
  }

  List<Widget> _genericHeaterTiles(int count) {
    return List.generate(
      count,
      (index) => _HeaterMixinTile(
          machineUUID: machineUUID,
          heaterProvider: _controllerProvider(machineUUID).select((value) => value.value!.genericHeaters[index])),
    );
  }

  List<Widget> _temperatureSensorTiles(int count) {
    return List.generate(
        count,
        (index) => _TemperatureSensorTile(
            sensorProvider:
                _controllerProvider(machineUUID).select((value) => value.value!.temperatureSensors[index])));
  }

  List<Widget> _temperatureFanTiles(int count) {
    return List.generate(
        count,
        (index) => _TemperatureFanTile(
            machineUUID: machineUUID,
            tempFanProvider: _controllerProvider(machineUUID).select((value) => value.value!.temperatureFans[index])));
  }
}

class _HeaterMixinTile extends HookConsumerWidget {
  static const int _stillHotTemp = 50;

  const _HeaterMixinTile({Key? key, required this.machineUUID, required this.heaterProvider}) : super(key: key);
  final String machineUUID;
  final ProviderListenable<HeaterMixin> heaterProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_controllerProvider(machineUUID).notifier);
    var klippyCanReceiveCommands =
        ref.watch(_controllerProvider(machineUUID).select((value) => value.value!.klippyCanReceiveCommands));

    var genericHeater = ref.watch(heaterProvider);

    var spots = useState(<FlSpot>[]);

    var temperatureHistory = genericHeater.temperatureHistory;
    if (temperatureHistory != null) {
      List<double> sublist = temperatureHistory.sublist(max(0, temperatureHistory.length - 300));
      spots.value.clear();
      spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    }

    NumberFormat numberFormat = NumberFormat('0.0', context.locale.languageCode);
    ThemeData themeData = Theme.of(context);
    Color colorBg = themeData.colorScheme.surfaceVariant;
    if (genericHeater.target > 0 && klippyCanReceiveCommands) {
      colorBg = Color.alphaBlend(
          const Color.fromRGBO(178, 24, 24, 1).withOpacity(min(genericHeater.temperature / genericHeater.target, 1)),
          colorBg);
    } else if (genericHeater.temperature > _stillHotTemp) {
      colorBg = Color.alphaBlend(
          const Color.fromRGBO(243, 106, 65, 1.0).withOpacity(min(genericHeater.temperature / _stillHotTemp - 1, 1)),
          colorBg);
    }
    var name = beautifyName(genericHeater.name);

    return GraphCardWithButton(
        backgroundColor: colorBg,
        plotSpots: spots.value,
        buttonChild: const Text('general.set').tr(),
        onTap: klippyCanReceiveCommands ? () => controller.adjustHeater(genericHeater) : null,
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
                    Text('${numberFormat.format(genericHeater.temperature)} °C',
                        style: innerTheme.textTheme.titleLarge),
                    Text(genericHeater.target > 0
                        ? 'pages.dashboard.general.temp_card.heater_on'
                            .tr(args: [numberFormat.format(genericHeater.target)])
                        : 'general.off'.tr()),
                  ],
                ),
                AnimatedOpacity(
                  opacity: genericHeater.temperature > _stillHotTemp ? 1 : 0,
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

class _TemperatureSensorTile extends HookConsumerWidget {
  const _TemperatureSensorTile({Key? key, required this.sensorProvider}) : super(key: key);
  final ProviderListenable<TemperatureSensor> sensorProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TemperatureSensor temperatureSensor = ref.watch(sensorProvider);

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

class _TemperatureFanTile extends HookConsumerWidget {
  static const double icoSize = 30;

  const _TemperatureFanTile({Key? key, required this.tempFanProvider, required this.machineUUID}) : super(key: key);
  final ProviderListenable<TemperatureFan> tempFanProvider;
  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TemperatureFan temperatureFan = ref.watch(tempFanProvider);
    var controller = ref.watch(_controllerProvider(machineUUID).notifier);
    var klippyCanReceiveCommands =
        ref.watch(_controllerProvider(machineUUID).selectAs((value) => value.klippyCanReceiveCommands)).value!;

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
      onTap: klippyCanReceiveCommands ? () => controller.editTemperatureFan(temperatureFan) : null,
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
                  'pages.dashboard.general.temp_card.heater_on'.tr(args: [temperatureFan.target.toStringAsFixed(1)]),
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

@riverpod
class _Controller extends _$Controller {
  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.timeoutKeepAlive();

    var printerProviderr = printerProvider(machineUUID);
    var klipperProviderr = klipperProvider(machineUUID);

    var klippyCanReceiveCommands =
        ref.watchAsSubject(klipperProviderr.selectAs((value) => value.klippyCanReceiveCommands));
    var extruders = ref.watchAsSubject(printerProviderr.selectAs((value) => value.extruders));
    var genericHeaters = ref.watchAsSubject(printerProviderr.selectAs(
        (value) => value.genericHeaters.values.where((e) => !e.name.startsWith('_')).toList(growable: false)));
    var temperatureSensors = ref.watchAsSubject(printerProviderr.selectAs(
        (value) => value.temperatureSensors.values.where((e) => !e.name.startsWith('_')).toList(growable: false)));
    var temperatureFans = ref.watchAsSubject(printerProviderr.selectAs((value) =>
        value.fans.values.whereType<TemperatureFan>().where((e) => !e.name.startsWith('_')).toList(growable: false)));
    var heaterBed = ref.watchAsSubject(printerProviderr.selectAs((value) => value.heaterBed));

    yield* Rx.combineLatest6(
        klippyCanReceiveCommands,
        extruders,
        genericHeaters,
        temperatureSensors,
        temperatureFans,
        heaterBed,
        (a, b, c, d, e, f) => _Model(
              klippyCanReceiveCommands: a,
              extruders: b,
              genericHeaters: c,
              temperatureSensors: d,
              temperatureFans: e,
              heaterBed: f,
            ));
  }

  adjustHeater(HeaterMixin heater) {
    double? maxValue;
    var configFile = ref.read(printerProvider(machineUUID).selectAs((value) => value.configFile)).value!;
    if (heater is Extruder) {
      maxValue = configFile.extruders[heater.name]?.maxTemp;
    } else if (heater is HeaterBed) {
      maxValue = configFile.configHeaterBed?.maxTemp;
    } else if (heater is GenericHeater) {
      maxValue = configFile.genericHeaters[heater.name.toLowerCase()]?.maxTemp;
    }

    _dialogService
        .show(DialogRequest(
            type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
                ? DialogType.numEdit
                : DialogType.rangeEdit,
            title: "Edit ${beautifyName(heater.name)} Temperature",
            cancelBtn: tr('general.cancel'),
            confirmBtn: tr('general.confirm'),
            data: NumberEditDialogArguments(current: heater.target, min: 0, max: maxValue ?? 150)))
        .then((value) {
      if (value == null || !value.confirmed || value.data == null) return;

      num v = value.data;
      _printerService.setHeaterTemperature(heater.name, v.toInt());
    });
  }

  editTemperatureFan(TemperatureFan temperatureFan) {
    var configFan =
        ref.read(printerProvider(machineUUID).selectAs((value) => value.configFile.fans[temperatureFan.name])).value!;

    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
            type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
                ? DialogType.numEdit
                : DialogType.rangeEdit,
            title: 'Edit Temperature Fan ${beautifyName(temperatureFan.name)}',
            cancelBtn: tr('general.cancel'),
            confirmBtn: tr('general.confirm'),
            data: NumberEditDialogArguments(
              current: temperatureFan.target.round(),
              min: (configFan is ConfigTemperatureFan) ? configFan.minTemp : 0,
              max: (configFan is ConfigTemperatureFan) ? configFan.maxTemp : 100,
            )))
        .then((value) {
      if (value == null || !value.confirmed || value.data == null) return;
      num v = value.data;
      ref.read(printerServiceSelectedProvider).setTemperatureFanTarget(temperatureFan.name, v.toInt());
    });
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required List<Extruder> extruders,
    required List<GenericHeater> genericHeaters,
    required List<TemperatureSensor> temperatureSensors,
    required List<TemperatureFan> temperatureFans,
    HeaterBed? heaterBed,
  }) = __Model;

  bool get hasPrintBed => heaterBed != null;
}
