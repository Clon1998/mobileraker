/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/dto/config/config_output.dart';
import 'package:common/data/dto/config/led/config_dumb_led.dart';
import 'package:common/data/dto/config/led/config_led.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_sensor.dart';
import 'package:common/data/dto/machine/leds/addressable_led.dart';
import 'package:common/data/dto/machine/leds/dumb_led.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:common/data/dto/machine/output_pin.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/horizontal_scroll_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
import '../../../components/dialog/edit_form/num_edit_form_dialog.dart';
import '../../../components/dialog/led_rgbw/led_rgbw_dialog_controller.dart';

part 'pins_card.freezed.dart';
part 'pins_card.g.dart';

class PinsCard extends HookConsumerWidget {
  const PinsCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview();
  }

  static Widget loading() {
    return const _PinsCardLoading();
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    logger.i('Rebuilding pins card for $machineUUID');
    return AsyncGuard(
      animate: true,
      debugLabel: 'PinsCard-$machineUUID',
      toGuard: _pinsCardControllerProvider(machineUUID).selectAs((data) => data.showCard),
      childOnLoading: const _PinsCardLoading(),
      childOnData: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CardTitle(machineUUID: machineUUID),
            _CardBody(machineUUID: machineUUID),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Preview extends HookWidget {
  static const String _machineUUID = 'preview';

  const _Preview({super.key});

  @override
  Widget build(BuildContext context) {
    useAutomaticKeepAlive();
    return ProviderScope(
      overrides: [
        _pinsCardControllerProvider(_machineUUID).overrideWith(_PinsCardPreviewController.new),
      ],
      child: const PinsCard(machineUUID: _machineUUID),
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
            HorizontalScrollSkeleton(
              contentTextStyles: [
                themeData.textTheme.bodySmall,
                themeData.textTheme.headlineSmall,
              ],
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

    var elementCount =
        ref.watch(_pinsCardControllerProvider(machineUUID).selectRequireValue((data) => data.elements.length));

    return AdaptiveHorizontalScroll(
      pageStorageKey: 'pins$machineUUID',
      children: [
        for (var i = 0; i < elementCount; i++)
          _Element(
            // ignore: avoid-unsafe-collection-methods
            provider: _pinsCardControllerProvider(machineUUID).selectRequireValue((value) => value.elements[i]),
            machineUUID: machineUUID,
          ),
      ],
    );
  }
}

class _Element extends ConsumerWidget {
  const _Element({super.key, required this.machineUUID, required this.provider});

  final String machineUUID;
  final ProviderListenable provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var element = ref.watch(provider);

    return switch (element) {
      Led() => _Led(led: element, machineUUID: machineUUID),
      OutputPin() => _Output(pin: element, machineUUID: machineUUID),
      FilamentSensor() => _FilamentSensor(sensor: element, machineUUID: machineUUID),
      _ => throw ArgumentError('Unknown element type'),
    };
  }
}

class _Output extends ConsumerWidget {
  const _Output({super.key, required this.pin, required this.machineUUID});

  final OutputPin pin;
  final String machineUUID;

  String pinValue(double v, String locale) {
    if (v > 0) return NumberFormat('0.##', locale).format(v);

    return 'general.off'.tr();
  }

  @override
  Widget build(_, WidgetRef ref) {
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
                AutoSizeText(
                  beautifiedName,
                  minFontSize: 8,
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
              AutoSizeText(
                beautifiedName,
                minFontSize: 8,
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
  const _Led({super.key, required this.led, required this.machineUUID});

  final Led led;
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
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      beautifiedName,
                      minFontSize: 8,
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

  const _FilamentSensor({super.key, required this.sensor, required this.machineUUID});

  final FilamentSensor sensor;
  final String machineUUID;

  @override
  Widget build(_, WidgetRef ref) {
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
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      beautifiedName,
                      minFontSize: 8,
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
              ),
              AnimatedSwitcher(
                // duration: Duration(milliseconds: 5000),
                duration: kThemeAnimationDuration,
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  key: ValueKey(sensor),
                  switch (sensor) {
                    FilamentSensor(enabled: true, filamentDetected: false) => Icons.warning_amber,
                    FilamentSensor(enabled: false) => Icons.sensors_off,
                    _ => Icons.sensors,
                  },
                  size: _iconSize,
                  // color: sensor.enabled ? Colors.green : Colors.white,
                ),
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
    var ordering = await ref.watch(machineSettingsProvider(machineUUID).selectAsync((value) => value.miscOrdering));
    // This might be WAY to fine grained. Riverpod will check based on the emitted value if the widget should rebuild.
    // This means that if the value is the same, the widget will not rebuild.
    // Otherwise Riverpod will check the same for us in the SelectAsync/SelectAs method. So we can directly get the RAW provider anyway!
    var klippyCanReceiveCommands =
        ref.watchAsSubject(klipperProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands));

    var elements = ref
        .watchAsSubject(printerProvider(machineUUID).selectAs((value) {
      var leds = value.leds;
      var filamentSensors = value.filamentSensors;
      var pins = value.outputPins;

      return [
        ...leds.values,
        ...pins.values,
        ...filamentSensors.values,
      ];
    }))
        // Use map here since this prevents to many operations if the original list not changes!
        .map((elements) {
      var output = <dynamic>[];

      for (var el in elements) {
        switch (el) {
          case Led():
            if (el.name.startsWith('_')) continue;
            break;
          case OutputPin():
            if (el.name.startsWith('_')) continue;
            break;
          case FilamentSensor():
            if (el.name.startsWith('_')) continue;
            break;
          default:
            continue;
        }
        output.add(el);
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

    var configFile = ref.watchAsSubject(printerProvider(machineUUID).selectAs((data) => data.configFile));

    yield* Rx.combineLatest3(
      klippyCanReceiveCommands,
      elements,
      configFile,
      (a, b, c) => _Model(
        klippyCanReceiveCommands: a,
        elements: b,
        ledConfig: c.leds,
        pinConfig: c.outputs,
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

class _PinsCardPreviewController extends _PinsCardController {
  @override
  Stream<_Model> build(String machineUUID) {
    state = const AsyncValue.data(_Model(
      klippyCanReceiveCommands: true,
      elements: [
        OutputPin(name: 'Preview Pin', value: 0),
        DumbLed(name: 'Preview Led'),
      ],
      ledConfig: {
        'preview led': ConfigDumbLed(
          name: 'preview led',
        ),
      },
      pinConfig: {
        'preview pin': ConfigOutput(
          name: 'preview pin',
          pwm: true,
          scale: 1,
        ),
      },
    ));

    return const Stream.empty();
  }

  @override
  Future<void> onEditPin(OutputPin pin) async {
    // Do nothing in preview mode
  }

  @override
  void onUpdateBinaryPin(OutputPin pin, bool value) {
    // Do nothing in preview mode
  }

  @override
  Future<void> onUpdateFilamentSensor(FilamentSensor sensor, bool value) async {
    // Do nothing in preview mode
  }

  @override
  Future<void> onEditLed(Led led) async {
    // Do nothing in preview mode
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required List<dynamic> elements,
    required Map<String, ConfigLed> ledConfig,
    required Map<String, ConfigOutput> pinConfig,
  }) = __Model;

  bool get showCard => elements.isNotEmpty;
}
