/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/dto/config/fan/config_temperature_fan.dart';
import 'package:common/data/dto/machine/fans/temperature_fan.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/heaters/generic_heater.dart';
import 'package:common/data/dto/machine/heaters/heater_bed.dart';
import 'package:common/data/dto/machine/heaters/heater_mixin.dart';
import 'package:common/data/dto/machine/printer_builder.dart';
import 'package:common/data/dto/machine/sensor_mixin.dart';
import 'package:common/data/dto/machine/temperature_sensor.dart';
import 'package:common/data/dto/machine/z_thermal_adjust.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
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
import '../../../../components/dialog/edit_form/num_edit_form_dialog.dart';
import '../../../../components/graph_card_with_button.dart';
import '../../../../components/spinning_fan.dart';
import 'temperature_sensor_preset_card.dart';

part 'heater_sensor_card.freezed.dart';
part 'heater_sensor_card.g.dart';

class HeaterSensorCard extends StatelessWidget {
  const HeaterSensorCard({super.key, required this.machineUUID, this.trailing});

  static Widget preview() {
    return const _HeaterSensorCardPreview();
  }

  final String machineUUID;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AsyncGuard(
      animate: true,
      debugLabel: 'HeaterSensorCard-$machineUUID',
      toGuard: _controllerProvider(machineUUID).selectAs((data) => true),
      childOnLoading: const HeaterSensorPresetCardLoading(),
      childOnData: Card(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            children: [
              HeaterSensorPresetCardTitle(
                machineUUID: machineUUID,
                title: const Text('pages.dashboard.general.temp_card.title').tr(),
                trailing: trailing,
              ),
              _CardBody(machineUUID: machineUUID),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaterSensorCardPreview extends StatefulWidget {
  static const String _machineUUID = 'preview';

  const _HeaterSensorCardPreview({super.key});

  @override
  State<_HeaterSensorCardPreview> createState() => _HeaterSensorCardPreviewState();
}

class _HeaterSensorCardPreviewState extends State<_HeaterSensorCardPreview> {
  late final Widget s;

  @override
  void initState() {
    super.initState();
    s = ProviderScope(
      overrides: [
        _controllerProvider(_HeaterSensorCardPreview._machineUUID).overrideWith(() {
          return _PreviewController();
        }),
        printerProvider(_HeaterSensorCardPreview._machineUUID)
            .overrideWith((provider) => Stream.value(PrinterBuilder.preview().build())),
      ],
      child: const HeaterSensorCard(machineUUID: _HeaterSensorCardPreview._machineUUID),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(_HeaterSensorCardPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    // super.build(context);

    return s;
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ROHE model nutzung ist AA. Wenn eine der listen sich ändert wird alles neu gebaut! Lieber einzelne Selects darauf!
    var provider = _controllerProvider(machineUUID);

    var sensors = ref.watch(provider.selectRequireValue((value) => value.sensors.length));
    logger.w('Rebuilding HeaterSensorCard');

    return AdaptiveHorizontalScroll(
      snap: true,
      pageStorageKey: 'temps$machineUUID',
      children: [
        for (var i = 0; i < sensors; i++)
          _SensorMixinTile(
            machineUUID: machineUUID,
            sensorProvider: _controllerProvider(machineUUID).selectRequireValue((value) => value.sensors[i]),
          ),
      ],
    );
  }
}

class _SensorMixinTile extends ConsumerWidget {
  const _SensorMixinTile({super.key, required this.machineUUID, required this.sensorProvider});

  final String machineUUID;
  final ProviderListenable<SensorMixin> sensorProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var sensor = ref.watch(sensorProvider);
    // logger.i('Rebuilding SensorMixinTile ${sensor.name}');

    return switch (sensor) {
      HeaterMixin() => _HeaterMixinTile(
          machineUUID: machineUUID,
          heater: sensor,
        ),
      TemperatureSensor() => _TemperatureSensorTile(
          temperatureSensor: sensor,
        ),
      TemperatureFan() => _TemperatureFanTile(
          machineUUID: machineUUID,
          temperatureFan: sensor,
        ),
      ZThermalAdjust() => _ZThermalAdjustTile(
          machineUUID: machineUUID,
          zThermalAdjust: sensor,
        ),
      _ => throw UnimplementedError(),
    };
  }
}

class _HeaterMixinTile extends HookConsumerWidget {
  static const int _stillHotTemp = 50;

  const _HeaterMixinTile({
    super.key,
    required this.machineUUID,
    required this.heater,
  });

  final String machineUUID;
  final HeaterMixin heater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_controllerProvider(machineUUID).notifier);
    var klippyCanReceiveCommands =
        ref.watch(_controllerProvider(machineUUID).selectRequireValue((value) => value.klippyCanReceiveCommands));

    var spots = useRef(<FlSpot>[]);

    var temperatureHistory = heater.temperatureHistory;
    if (temperatureHistory != null) {
      List<double> sublist = temperatureHistory.sublist(max(0, temperatureHistory.length - 300));
      spots.value.clear();
      spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    }

    NumberFormat numberFormat = NumberFormat('0.0', context.locale.toStringWithSeparator());
    ThemeData themeData = Theme.of(context);
    Color colorBg = themeData.colorScheme.surfaceVariant;
    if (heater.target > 0 && klippyCanReceiveCommands) {
      colorBg = Color.alphaBlend(
        const Color.fromRGBO(178, 24, 24, 1).withOpacity(
          min(heater.temperature / heater.target, 1),
        ),
        colorBg,
      );
    } else if (heater.temperature > _stillHotTemp) {
      colorBg = Color.alphaBlend(
        const Color.fromRGBO(243, 106, 65, 1.0).withOpacity(
          min(heater.temperature / _stillHotTemp - 1, 1),
        ),
        colorBg,
      );
    }
    var name = beautifyName(heater.name);

    return GraphCardWithButton(
      backgroundColor: colorBg,
      plotSpots: spots.value,
      buttonChild: const Text('general.set').tr(),
      onTap: klippyCanReceiveCommands ? () => controller.adjustHeater(heater) : null,
      builder: (BuildContext context) {
        var innerTheme = Theme.of(context);
        return Tooltip(
          message: name,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      name,
                      minFontSize: 8,
                      style: innerTheme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${numberFormat.format(heater.temperature)} °C',
                      style: innerTheme.textTheme.titleLarge,
                    ),
                    Text(
                      heater.target > 0
                          ? 'pages.dashboard.general.temp_card.heater_on'.tr(
                              args: [numberFormat.format(heater.target)],
                            )
                          : 'general.off'.tr(),
                      style: innerTheme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: heater.temperature > _stillHotTemp ? 1 : 0,
                duration: kThemeAnimationDuration,
                child: Tooltip(
                  message: '$name is still hot!',
                  child: const Icon(Icons.do_not_touch_outlined),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TemperatureSensorTile extends HookConsumerWidget {
  const _TemperatureSensorTile({super.key, required this.temperatureSensor});

  final TemperatureSensor temperatureSensor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var spots = useRef(<FlSpot>[]);
    var temperatureHistory = temperatureSensor.temperatureHistory;

    if (temperatureHistory != null) {
      List<double> sublist = temperatureHistory.sublist(max(0, temperatureHistory.length - 300));
      spots.value.clear();
      spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    }
    var beautifiedNamed = beautifyName(temperatureSensor.name);
    var numberFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);
    return GraphCardWithButton(
      plotSpots: spots.value,
      buttonChild: const Text('pages.dashboard.general.temp_card.btn_thermistor').tr(),
      onTap: null,
      builder: (context) {
        final themeData = Theme.of(context);
        return Tooltip(
          message: beautifiedNamed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoSizeText(
                beautifiedNamed,
                minFontSize: 8,
                style: themeData.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${numberFormat.format(temperatureSensor.temperature)} °C',
                style: themeData.textTheme.titleLarge,
              ),
              Text(
                '${numberFormat.format(temperatureSensor.measuredMaxTemp)} °C max',
                style: themeData.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TemperatureFanTile extends HookConsumerWidget {
  static const double icoSize = 30;

  const _TemperatureFanTile({
    super.key,
    required this.temperatureFan,
    required this.machineUUID,
  });

  final TemperatureFan temperatureFan;
  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_controllerProvider(machineUUID).notifier);
    var klippyCanReceiveCommands =
        ref.watch(_controllerProvider(machineUUID).selectRequireValue((value) => value.klippyCanReceiveCommands));

    var spots = useRef(<FlSpot>[]);
    var temperatureHistory = temperatureFan.temperatureHistory;
    //
    if (temperatureHistory != null) {
      List<double> sublist = temperatureHistory.sublist(max(0, temperatureHistory.length - 300));
      spots.value.clear();
      spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    }
    var beautifiedNamed = beautifyName(temperatureFan.name);
    var numberFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);

    return GraphCardWithButton(
      plotSpots: spots.value,
      buttonChild: const Text('general.set').tr(),
      onTap: klippyCanReceiveCommands ? () => controller.editTemperatureFan(temperatureFan) : null,
      builder: (context) {
        final themeData = Theme.of(context);
        return Tooltip(
          message: beautifiedNamed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      beautifiedNamed,
                      minFontSize: 8,
                      style: themeData.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${numberFormat.format(temperatureFan.temperature)} °C',
                      style: themeData.textTheme.titleLarge,
                    ),
                    Text(
                      'pages.dashboard.general.temp_card.heater_on'
                          .tr(args: [numberFormat.format(temperatureFan.target)]),
                      style: themeData.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              temperatureFan.speed > 0
                  ? const SpinningFan(size: icoSize)
                  : const Icon(FlutterIcons.fan_off_mco, size: icoSize),
            ],
          ),
        );
      },
    );
  }
}

class _ZThermalAdjustTile extends HookConsumerWidget {
  static const double icoSize = 30;

  const _ZThermalAdjustTile({
    super.key,
    required this.zThermalAdjust,
    required this.machineUUID,
  });

  final ZThermalAdjust zThermalAdjust;
  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_controllerProvider(machineUUID).notifier);
    var klippyCanReceiveCommands =
        ref.watch(_controllerProvider(machineUUID).selectRequireValue((value) => value.klippyCanReceiveCommands));

    var spots = useRef(<FlSpot>[]);
    var temperatureHistory = zThermalAdjust.temperatureHistory;
    //
    if (temperatureHistory != null) {
      List<double> sublist = temperatureHistory.sublist(max(0, temperatureHistory.length - 300));
      spots.value.clear();
      spots.value.addAll(sublist.mapIndex((e, i) => FlSpot(i.toDouble(), e)));
    }
    var beautifiedNamed = beautifyName(zThermalAdjust.name);
    var numberFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);

    return GraphCardWithButton(
      plotSpots: spots.value,
      buttonChild: const Text('pages.dashboard.general.temp_card.btn_thermistor').tr(),
      onTap: null,
      builder: (context) {
        final themeData = Theme.of(context);
        return Tooltip(
          message: beautifiedNamed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoSizeText(
                beautifiedNamed,
                minFontSize: 8,
                style: themeData.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${numberFormat.format(zThermalAdjust.temperature)} °C',
                style: themeData.textTheme.titleLarge,
              ),
              Text(
                numberFormat.formatMillimeters(zThermalAdjust.currentZAdjust, useMicro: true),
              ),
            ],
          ),
        );
      },
    );
  }
}

@riverpod
class _Controller extends _$Controller {
  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  @override
  Stream<_Model> build(String machineUUID) async* {
    logger.i('Rebuilding HeaterSensorCard for machine $machineUUID');
    ref.keepAliveFor();

    var printerProviderr = printerProvider(machineUUID);
    var klipperProviderr = klipperProvider(machineUUID);

    var ordering = await ref.watch(machineSettingsProvider(machineUUID).selectAsync((value) => value.tempOrdering));
    var klippyCanReceiveCommands = ref.watchAsSubject(
      klipperProviderr.selectAs((value) => value.klippyCanReceiveCommands),
    );
    // Kinda overkill to use a stream for each value, I am pretty sure I could just use printer directly too !
    // Pro:
    // - Pontentially less updates since only specifc values are listened to
    // Con:
    // - More boilerPlate
    // - Potentially more updates since more streams are listened to?

    final senors = ref.watchAsSubject(printerProviderr.selectAs((value) {
      final extruders = value.extruders;
      final genericHeaters = value.genericHeaters;
      final tempSensors = value.temperatureSensors;
      final tempFans = value.fans.values.whereType<TemperatureFan>().toList();
      final zAdjust = value.zThermalAdjust;

      return [
        ...extruders,
        if (value.heaterBed != null) value.heaterBed!,
        ...genericHeaters.values,
        ...tempSensors.values,
        ...tempFans,
        if (zAdjust != null) zAdjust,
      ];
    }))
        // Use map here since this prevents to many operations if the original list not changes!
        .map((sensors) {
      var output = <SensorMixin>[];

      for (var sensor in sensors) {
        if (sensor.name.startsWith('_')) continue;
        output.add(sensor);
      }

      // Sort output by ordering, if ordering is not found it will be placed at the end
      output.sort((a, b) {
        var aIndex = ordering.indexWhere((element) => element.name == a.name);
        var bIndex = ordering.indexWhere((element) => element.name == b.name);

        if (aIndex == -1) aIndex = output.length;
        if (bIndex == -1) bIndex = output.length;

        return aIndex.compareTo(bIndex);
      });
      return output;
    });

    yield* Rx.combineLatest2(
      klippyCanReceiveCommands,
      senors,
      (a, b) => _Model(klippyCanReceiveCommands: a, sensors: b),
    );
  }

  adjustHeater(HeaterMixin heater) {
    double? maxValue;
    var configFile = ref.read(printerProvider(machineUUID).selectRequireValue((value) => value.configFile));
    if (heater is Extruder) {
      maxValue = configFile.extruders[heater.name]?.maxTemp;
    } else if (heater is HeaterBed) {
      maxValue = configFile.configHeaterBed?.maxTemp;
    } else if (heater is GenericHeater) {
      maxValue = configFile.genericHeaters[heater.configName]?.maxTemp;
    }

    _dialogService
        .show(DialogRequest(
      type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
          ? DialogType.numEdit
          : DialogType.rangeEdit,
      title: tr('dialogs.heater_temperature.title', args: [beautifyName(heater.name)]),
      dismissLabel: tr('general.cancel'),
      actionLabel: tr('general.confirm'),
      data: NumberEditDialogArguments(
        current: heater.target,
        min: 0,
        max: maxValue ?? 150,
      ),
    ))
        .then((value) {
      if (value == null || !value.confirmed || value.data == null) return;

      num v = value.data;
      _printerService.setHeaterTemperature(heater.name, v.toInt());
    });
  }

  editTemperatureFan(TemperatureFan temperatureFan) {
    var configFan = ref
        .read(printerProvider(machineUUID).selectAs((value) => value.configFile.fans[temperatureFan.configName]))
        .requireValue;

    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
          type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
              ? DialogType.numEdit
              : DialogType.rangeEdit,
          title: tr('dialogs.heater_temperature.title', args: [beautifyName(temperatureFan.name)]),
          data: NumberEditDialogArguments(
            current: temperatureFan.target.round(),
            min: (configFan is ConfigTemperatureFan) ? configFan.minTemp : 0,
            max: (configFan is ConfigTemperatureFan) ? configFan.maxTemp : 100,
          ),
        ))
        .then((value) {
      if (value == null || !value.confirmed || value.data == null) return;
      num v = value.data;
      ref.read(printerServiceSelectedProvider).setTemperatureFanTarget(temperatureFan.name, v.toInt());
    });
  }
}

class _PreviewController extends _Controller {
  @override
  Stream<_Model> build(String machineUUID) {
    logger.i('Rebuilding (preview) HeaterSensorCard._PreviewController for machine $machineUUID');
    ref.onDispose(() {
      logger.i('Disposing (preview) HeaterSensorCard._PreviewController for machine $machineUUID');
    });
    ref.keepAliveFor();
    state = AsyncValue.data(_Model(
      klippyCanReceiveCommands: true,
      sensors: [
        Extruder(
          temperature: 150,
          target: 200,
          num: 0,
          lastHistory: DateTime.now(),
          temperatureHistory: [60, 100, 120, 150],
        ),
        HeaterBed(
          temperature: 40,
          target: 60,
          lastHistory: DateTime.now(),
          temperatureHistory: [100, 88, 70, 40, 44, 52, 60],
        )
      ],
    ));

    return const Stream.empty();
  }

  @override
  // ignore: no-empty-block
  adjustHeater(HeaterMixin heater) {
    // No action due to preview
  }

  @override
  // ignore: no-empty-block
  editTemperatureFan(TemperatureFan temperatureFan) {
    // No action due to preview
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required List<SensorMixin> sensors,
  }) = __Model;
}
