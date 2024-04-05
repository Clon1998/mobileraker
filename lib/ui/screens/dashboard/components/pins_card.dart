/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/config/config_output.dart';
import 'package:common/data/dto/config/led/config_dumb_led.dart';
import 'package:common/data/dto/config/led/config_led.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_sensor.dart';
import 'package:common/data/dto/machine/leds/addressable_led.dart';
import 'package:common/data/dto/machine/leds/dumb_led.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:common/data/dto/machine/output_pin.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/card_with_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/util/extensions/pixel_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../service/ui/dialog_service_impl.dart';
import '../../../components/adaptive_horizontal_scroll.dart';
import '../../../components/card_with_button.dart';
import '../../../components/card_with_switch.dart';
import '../../../components/dialog/edit_form/num_edit_form_controller.dart';
import '../../../components/dialog/led_rgbw/led_rgbw_dialog_controller.dart';

part 'pins_card.freezed.dart';
part 'pins_card.g.dart';

class PinsCard extends ConsumerWidget {
  const PinsCard({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var showLoading =
        ref.watch(_pinsCardControllerProvider(machineUUID).select((value) => value.isLoading && !value.isReloading));

    if (showLoading) {
      return const _PinsCardLoading();
    }
    var showCard = ref.watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.showCard));

    if (!showCard) {
      return const SizedBox.shrink();
    }

    logger.i('Rebuilding pins card');

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardTitle(machineUUID: machineUUID),
          _CardBody(machineUUID: machineUUID),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PinsCardLoading extends StatelessWidget {
  const _PinsCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Card(
      child: Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: themeData.colorScheme.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CardTitleSkeleton(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: CardWithSkeleton(
                          contentTextStyles: [
                            themeData.textTheme.bodySmall,
                            themeData.textTheme.headlineSmall,
                          ],
                        ),
                      ),
                      Flexible(
                        child: CardWithSkeleton(
                          contentTextStyles: [
                            themeData.textTheme.bodySmall,
                            themeData.textTheme.headlineSmall,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 5),
                    child: SizedBox(
                      width: 30,
                      height: 11,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends ConsumerWidget {
  const _CardTitle({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.total));

    logger.i('Rebuilding output card title');

    return ListTile(
      leading: const Icon(FlutterIcons.led_outline_mco),
      title: const Text('pages.dashboard.control.pin_card.title_misc').tr(),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('Rebuilding outputs card body');

    var pinsCount = ref.watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.pins.length));
    var ledsCount = ref.watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.leds.length));
    var filamentSensorsCount =
        ref.watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.filamentSensors.length));

    return AdaptiveHorizontalScroll(
      pageStorageKey: 'pins$machineUUID',
      children: [
        for (var i = 0; i < pinsCount; i++)
          _Output(
            // ignore: avoid-unsafe-collection-methods
            pinProvider: _pinsCardControllerProvider(machineUUID).selectRequireValue((value) => value.pins[i]),
            machineUUID: machineUUID,
          ),
        for (var i = 0; i < ledsCount; i++)
          _Led(
            // ignore: avoid-unsafe-collection-methods
            ledProvider: _pinsCardControllerProvider(machineUUID).selectRequireValue((value) => value.leds[i]),
            machineUUID: machineUUID,
          ),
        for (var i = 0; i < filamentSensorsCount; i++)
          _FilamentSensor(
            // ignore: avoid-unsafe-collection-methods
            sensorProvider:
                _pinsCardControllerProvider(machineUUID).selectRequireValue((value) => value.filamentSensors[i]),
            machineUUID: machineUUID,
          ),
      ],
    );
  }
}

class _Output extends ConsumerWidget {
  const _Output({super.key, required this.pinProvider, required this.machineUUID});

  final ProviderListenable<OutputPin> pinProvider;
  final String machineUUID;

  String pinValue(double v, String locale) {
    if (v > 0) return NumberFormat('0.##', locale).format(v);

    return 'general.off'.tr();
  }

  @override
  Widget build(_, WidgetRef ref) {
    var pin = ref.watch(pinProvider);
    var klippyCanReceiveCommands =
        ref.watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.klippyCanReceiveCommands));
    var pinConfig = ref
        .watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.pinConfig[pin.configName]));

    var controller = ref.watch(_pinsCardControllerProvider(machineUUID).notifier);

    logger.i('Rebuilding pin card for ${pin.name}');

    if (pinConfig?.pwm == false) {
      return CardWithSwitch(
        value: pin.value > 0,
        onChanged: klippyCanReceiveCommands ? (v) => controller.onUpdateBinaryPin(pin, v) : null,
        builder: (context) {
          var textTheme = Theme.of(context).textTheme;
          var beautifiedName = beautifyName(pin.name);
          return Tooltip(
            message: beautifiedName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beautifiedName,
                  style: textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  pin.value > 0 ? 'general.on'.tr() : 'general.off'.tr(),
                  style: textTheme.headlineSmall,
                ),
              ],
            ),
          );
        },
      );
    }

    return CardWithButton(
      buttonChild: const Text('general.set').tr(),
      onTap: klippyCanReceiveCommands ? () => controller.onEditPin(pin) : null,
      builder: (context) {
        var textTheme = Theme.of(context).textTheme;
        var beautifiedName = beautifyName(pin.name);
        return Tooltip(
          message: beautifiedName,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                beautifiedName,
                style: textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                pinValue(
                  pin.value * (pinConfig?.scale ?? 1),
                  context.locale.toStringWithSeparator(),
                ),
                style: textTheme.headlineSmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Led extends ConsumerWidget {
  const _Led({super.key, required this.ledProvider, required this.machineUUID});

  final ProviderListenable<Led> ledProvider;
  final String machineUUID;

  static const double _iconSize = 30;
  static const int _maxPixelInGradient = 5;

  Color dumbLedStatusColor(DumbLed led, ConfigLed? ledConfig) {
    Pixel pixel = led.color;
    if (!pixel.hasColor) {
      return Colors.white;
    }
    if (ledConfig?.isSingleColor == true) {
      var dumpLedConfig = ledConfig as ConfigDumbLed;
      Color color = Colors.white;
      if (dumpLedConfig.hasRed) {
        color = Colors.red;
      }
      if (dumpLedConfig.hasGreen) {
        color = Colors.green;
      }
      if (dumpLedConfig.hasBlue) {
        color = Colors.blue;
      }
      return color.darken(((1 - pixel.white) * 10).toInt());
    }

    return pixel.rgbwColor;
  }

  String statusText(Led led, ConfigLed? ledConfig, String locale) {
    if (led is DumbLed && ledConfig?.isSingleColor == false && led.color.hasColor ||
        led is AddressableLed && led.pixels.any((e) => e.hasColor)) {
      return 'general.on'.tr();
    }

    if (led is DumbLed && ledConfig?.isSingleColor == true) {
      List<double> rgbw = led.color.asList();
      var value = rgbw.reduce(max);
      if (value > 0) return NumberFormat('0%', locale).format(value);
    }
    return 'general.off'.tr();
  }

  Widget statusWidget(Led led, ConfigLed? ledConfig) {
    bool power = false;
    if (led is DumbLed) {
      power = led.color.hasColor;
    } else if (led is AddressableLed) {
      power = led.pixels.any((e) => e.hasColor);
    }

    if (!power) {
      return const Icon(
        Icons.circle_outlined,
        size: _iconSize,
        color: Colors.white,
      );
    }

    List<Color> colors;
    if (led is DumbLed) {
      colors = [dumbLedStatusColor(led, ledConfig)];
    } else if (led is AddressableLed) {
      colors = led.pixels
          .sublist(0, min(led.pixels.length, _maxPixelInGradient))
          .map((e) => e.rgbwColor)
          .toList(growable: false);
    } else {
      throw ArgumentError('Unknown LED type');
    }

    if (colors.length <= 1) {
      Color c = (colors.length == 1) ? colors.first : Colors.white;
      return Icon(Icons.circle, size: _iconSize, color: c);
    }

    return ShaderMask(
      shaderCallback: (bounds) => SweepGradient(colors: colors).createShader(bounds),
      child: const Icon(Icons.circle, size: _iconSize),
    );
  }

  @override
  Widget build(_, WidgetRef ref) {
    Led led = ref.watch(ledProvider);
    var ledConfig = ref
        .watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.ledConfig[led.configName]));
    var klippyCanReceiveCommands =
        ref.watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.klippyCanReceiveCommands));

    var controller = ref.watch(_pinsCardControllerProvider(machineUUID).notifier);

    logger.i('Rebuilding led card for ${led.name}');

    return CardWithButton(
      buttonChild: const Text('general.set').tr(),
      onTap: klippyCanReceiveCommands ? () => controller.onEditLed(led) : null,
      builder: (context) {
        var textTheme = Theme.of(context).textTheme;
        var beautifiedName = beautifyName(led.name);
        return Tooltip(
          message: beautifiedName,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beautifiedName,
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    statusText(led, ledConfig, context.locale.toStringWithSeparator()),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              statusWidget(led, ledConfig),
            ],
          ),
        );
      },
    );
  }
}

class _FilamentSensor extends ConsumerWidget {
  static const double _iconSize = 30;

  const _FilamentSensor({super.key, required this.sensorProvider, required this.machineUUID});

  final ProviderListenable<FilamentSensor> sensorProvider;
  final String machineUUID;

  @override
  Widget build(_, WidgetRef ref) {
    var sensor = ref.watch(sensorProvider);
    var klippyCanReceiveCommands =
        ref.watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.klippyCanReceiveCommands));

    var controller = ref.watch(_pinsCardControllerProvider(machineUUID).notifier);

    logger.i('Rebuilding filament sensor card for ${sensor.name}');

    return CardWithSwitch(
      value: sensor.enabled,
      onChanged: klippyCanReceiveCommands ? (v) => controller.onUpdateFilamentSensor(sensor, v) : null,
      builder: (context) {
        var textTheme = Theme.of(context).textTheme;
        var beautifiedName = beautifyName(sensor.name);
        return Tooltip(
          message: beautifiedName,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beautifiedName,
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    switch (sensor) {
                      FilamentSensor(enabled: true, filamentDetected: true) =>
                        'pages.dashboard.control.pin_card.filament_sensor.detected'.tr(),
                      FilamentSensor(enabled: true, filamentDetected: false) =>
                        'pages.dashboard.control.pin_card.filament_sensor.not_detected'.tr(),
                      _ => 'general.disabled'.tr(),
                    },
                    style: textTheme.headlineSmall,
                  ),
                ],
              ),
              Icon(
                sensor.enabled ? Icons.sensors : Icons.sensors_off,
                size: _iconSize,
                // color: sensor.enabled ? Colors.green : Colors.white,
              ),
            ],
          ),
        );
      },
    );
  }
}

@riverpod
class _PinsCardController extends _$PinsCardController {
  DialogService get _dialogService => ref.read(dialogServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  DialogType get _dialogMode {
    return ref.read(boolSettingProvider(AppSettingKeys.defaultNumEditMode)) ? DialogType.numEdit : DialogType.rangeEdit;
  }

  @override
  Stream<_Model> build(String machineUUID) async* {
    logger.i('Rebuilding pinsCardController for $machineUUID');

    // This might be WAY to fine grained. Riverpod will check based on the emitted value if the widget should rebuild.
    // This means that if the value is the same, the widget will not rebuild.
    // Otherwise Riverpod will check the same for us in the SelectAsync/SelectAs method. So we can directly get the RAW provider anyway!
    var klippyCanReceiveCommands =
        ref.watchAsSubject(klipperProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands));
    var leds = ref.watchAsSubject(printerProvider(machineUUID).selectAs(
        (data) => data.leds.values.where((element) => !element.name.startsWith('_')).toList(growable: false)));
    var ledConfig = ref.watchAsSubject(printerProvider(machineUUID).selectAs((data) => data.configFile.leds));
    var pins = ref.watchAsSubject(printerProvider(machineUUID).selectAs(
        (data) => data.outputPins.values.where((element) => !element.name.startsWith('_')).toList(growable: false)));
    var pinConfig = ref.watchAsSubject(printerProvider(machineUUID).selectAs((data) => data.configFile.outputs));

    var filamentSensors = ref.watchAsSubject(printerProvider(machineUUID).selectAs((data) =>
        data.filamentSensors.values.where((element) => !element.name.startsWith('_')).toList(growable: false)));

    yield* Rx.combineLatest6(
      klippyCanReceiveCommands,
      leds,
      ledConfig,
      pins,
      pinConfig,
      filamentSensors,
      (a, b, c, d, e, f) => _Model(
        klippyCanReceiveCommands: a,
        leds: b,
        ledConfig: c,
        pins: d,
        pinConfig: e,
        filamentSensors: f,
      ),
    );
  }

  Future<void> onEditPin(OutputPin pin) async {
    if (!state.hasValue) return;
    ConfigOutput? configOutput = state.requireValue.pinConfig[pin.configName];
    int fractionToShow = (configOutput == null || !configOutput.pwm) ? 0 : 2;

    var result = await _dialogService.show(DialogRequest(
      type: _dialogMode,
      title: '${tr('general.edit')} ${beautifyName(pin.name)}',
      cancelBtn: tr('general.cancel'),
      confirmBtn: tr('general.confirm'),
      data: NumberEditDialogArguments(
        current: pin.value * (configOutput?.scale ?? 1),
        min: 0,
        max: configOutput?.scale.toInt() ?? 1,
        fraction: fractionToShow,
      ),
    ));

    if (result case DialogResponse(confirmed: true, data: num v)) {
      _printerService.outputPin(pin.name, v.toDouble());
    }
  }

  void onUpdateBinaryPin(OutputPin pin, bool value) {
    _printerService.outputPin(pin.name, value ? 1 : 0);
  }

  Future<void> onUpdateFilamentSensor(FilamentSensor sensor, bool value) async {
    _printerService.filamentSensor(sensor.name, value);
  }

  Future<void> onEditLed(Led led) async {
    if (!state.hasValue) return;
    ConfigLed? configLed = state.requireValue.ledConfig[led.configName];
    if (configLed == null) return;

    String name = beautifyName(led.name);
    if (configLed.isSingleColor == true && configLed is ConfigDumbLed) {
      var result = await _dialogService.show(DialogRequest(
        type: _dialogMode,
        title: '${tr('general.edit')} $name %',
        cancelBtn: tr('general.cancel'),
        confirmBtn: tr('general.confirm'),
        data: NumberEditDialogArguments(
          current: (led as DumbLed).color.asList().reduce(max) * 100.round(),
          min: 0,
          max: 100,
        ),
      ));

      if (result case DialogResponse(confirmed: true, data: num v)) {
        double val = v.toInt() / 100;

        List<double> rgbw = [0, 0, 0, 0];
        if (configLed.hasRed) {
          rgbw[0] = val;
        } else if (configLed.hasGreen) {
          rgbw[1] = val;
        } else if (configLed.hasBlue) {
          rgbw[2] = val;
        } else if (configLed.hasWhite) {
          rgbw[3] = val;
        }
        _printerService.led(led.name, Pixel.fromList(rgbw));
      }

      return;
    }

    var result = await _dialogService.show(DialogRequest(
      type: DialogType.ledRGBW,
      data: LedRGBWDialogArgument(configLed, led),
    ));
    if (result case DialogResponse(confirmed: true, data: Color selectedColor)) {
      double white = 0;
      if (configLed.hasWhite && selectedColor.value == 0xFFFFFFFF) {
        white = 1;
      }

      Pixel pixel = Pixel.fromList([
        selectedColor.red / 255,
        selectedColor.green / 255,
        selectedColor.blue / 255,
        white,
      ]);

      _printerService.led(led.name, pixel);
    }
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required List<Led> leds,
    required Map<String, ConfigLed> ledConfig,
    required List<OutputPin> pins,
    required Map<String, ConfigOutput> pinConfig,
    required List<FilamentSensor> filamentSensors,
  }) = __Model;

  bool get showCard => leds.isNotEmpty || pins.isNotEmpty || filamentSensors.isNotEmpty;

  int get total => leds.length + pins.length + filamentSensors.length;
}
