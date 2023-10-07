/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:common/data/dto/config/led/config_dumb_led.dart';
import 'package:common/data/dto/config/led/config_led.dart';
import 'package:common/data/dto/machine/fans/generic_fan.dart';
import 'package:common/data/dto/machine/fans/named_fan.dart';
import 'package:common/data/dto/machine/leds/addressable_led.dart';
import 'package:common/data/dto/machine/leds/dumb_led.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:common/data/dto/machine/output_pin.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/moonraker_db/gcode_macro.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/card_with_switch.dart';
import 'package:mobileraker/ui/components/power_api_panel.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/control_tab_controller.dart';
import 'package:mobileraker/util/extensions/pixel_extension.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stringr/stringr.dart';

class ControlTab extends ConsumerWidget {
  const ControlTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(machinePrinterKlippySettingsProvider.selectAs((data) => true)).when(
        data: (data) {
          return PullToRefreshPrinter(
            child: ListView(
              key: const PageStorageKey<String>('cTab'),
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                if (ref
                        .watch(machinePrinterKlippySettingsProvider
                            .selectAs((value) => value.settings.macroGroups.isNotEmpty))
                        .valueOrNull ??
                    false)
                  const GcodeMacroCard(),
                if (ref
                        .watch(machinePrinterKlippySettingsProvider
                            .selectAs((value) => value.printerData.print.state != PrintState.printing))
                        .valueOrNull ??
                    false)
                  const ExtruderControlCard(),
                const FansCard(),
                if (ref
                        .watch(machinePrinterKlippySettingsProvider.selectAs(
                            (value) => value.printerData.outputPins.isNotEmpty || value.printerData.leds.isNotEmpty))
                        .valueOrNull ??
                    false)
                  const PinsCard(),
                if (ref
                        .watch(machinePrinterKlippySettingsProvider
                            .selectAs((value) => value.klippyData.components.contains('power')))
                        .valueOrNull ??
                    false)
                  const PowerApiCard(),
                const MultipliersCard(),
                const LimitsCard(),
              ],
            ),
          );
        },
        error: (e, s) {
          logger.e('Cought error in Controller tab', e, s);
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
                    // onPressed: model.showPrinterFetchingErrorDialog,
                    onPressed: () => ref.read(dialogServiceProvider).show(DialogRequest(
                        type: CommonDialogs.stacktrace,
                        title: e.runtimeType.toString(),
                        body: 'Exception:\n $e\n\n$s')),
                    child: const Text('Show Error'))
              ],
            ),
          );
        },
        loading: () => Center(
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
            ));
  }
}

class FansCard extends ConsumerWidget {
  const FansCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var fanLen = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs(
            (value) => value.printerData.fans.values.where((element) => !element.name.startsWith('_')).length))
        .valueOrNull!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                FlutterIcons.fan_mco,
              ),
              title: const Text('pages.dashboard.control.fan_card.title').plural(fanLen),
            ),
            AdaptiveHorizontalScroll(pageStorageKey: 'fans', children: [
              if (ref
                      .watch(
                          machinePrinterKlippySettingsProvider.selectAs((data) => data.printerData.isPrintFanAvailable))
                      .valueOrNull ==
                  true)
                const _PrintFan(),
              ...List.generate(fanLen, (index) {
                var fanProvider = machinePrinterKlippySettingsProvider.selectAs((value) =>
                    value.printerData.fans.values.where((element) => !element.name.startsWith('_')).elementAt(index));

                return _Fan(
                  fanProvider: fanProvider,
                );
              }),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PrintFan extends ConsumerWidget {
  const _PrintFan({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var fan =
        ref.watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.printerData.printFan)).valueOrNull;
    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    if (fan == null) {
      return const SizedBox.shrink();
    }

    return _FanCard(
      name: 'pages.dashboard.control.fan_card.part_fan'.tr(),
      speed: fan.speed,
      onTap: klippyCanReceiveCommands ? () => ref.read(controlTabControllerProvider.notifier).onEditPartFan(fan) : null,
    );
  }
}

class _Fan extends ConsumerWidget {
  const _Fan({Key? key, required this.fanProvider}) : super(key: key);

  final ProviderListenable<AsyncValue<NamedFan>> fanProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var fan = ref.watch(fanProvider).valueOrNull!;
    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;
    return _FanCard(
      name: beautifyName(fan.name),
      speed: fan.speed,
      onTap: klippyCanReceiveCommands && (fan is GenericFan)
          ? () => ref.read(controlTabControllerProvider.notifier).onEditGenericFan(fan)
          : null,
    );
  }
}

class _FanCard extends StatelessWidget {
  static const double icoSize = 30;

  final String name;
  final double speed;
  final VoidCallback? onTap;

  const _FanCard({
    Key? key,
    required this.name,
    required this.speed,
    this.onTap,
  }) : super(key: key);

  String get fanSpeed {
    double fanPerc = speed * 100;
    if (speed > 0) return '${fanPerc.toStringAsFixed(0)} %';
    return 'general.off'.tr();
  }

  @override
  Widget build(BuildContext context) {
    return CardWithButton(
        buttonChild: onTap == null
            ? const Text('pages.dashboard.control.fan_card.static_fan_btn').tr()
            : const Text('general.set').tr(),
        onTap: onTap,
        builder: (context) {
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
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(fanSpeed, style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
                speed > 0
                    ? const SpinningFan(size: icoSize)
                    : const Icon(
                        FlutterIcons.fan_off_mco,
                        size: icoSize,
                      ),
              ],
            ),
          );
        });
  }
}

class SpinningFan extends HookWidget {
  const SpinningFan({Key? key, required this.size}) : super(key: key);

  final double? size;

  @override
  Widget build(BuildContext context) {
    AnimationController animationController = useAnimationController(duration: const Duration(seconds: 3))..repeat();
    return RotationTransition(
      turns: animationController,
      child: Icon(FlutterIcons.fan_mco, size: size),
    );
  }
}

class ExtruderControlCard extends HookConsumerWidget {
  const ExtruderControlCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var activeExtruderIdx = ref.watch(machinePrinterKlippySettingsProvider.selectAs((value) {
      String activeIdx = value.printerData.toolhead.activeExtruder.substring(8);
      return int.tryParse(activeIdx) ?? 0;
    })).valueOrNull!;

    var minExtrudeTemp = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs(
            (value) => value.printerData.configFile.extruderForIndex(activeExtruderIdx)?.minExtrudeTemp ?? 170))
        .valueOrNull!;

    var canExtrude = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.printerData.extruders[activeExtruderIdx].temperature >= minExtrudeTemp))
        .valueOrNull!;

    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    var extruderSteps =
        ref.watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.settings.extrudeSteps)).valueOrNull!;

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
            title: Row(
              children: [
                const Text('pages.dashboard.control.extrude_card.title').tr(),
                AnimatedOpacity(
                  opacity: canExtrude ? 0 : 1,
                  duration: kThemeAnimationDuration,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Tooltip(
                      message: tr('pages.dashboard.control.extrude_card.cold_extrude_error',
                          args: [minExtrudeTemp.toStringAsFixed(0)]),
                      child: Icon(
                        Icons.severe_cold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                )
              ],
            ),
            trailing: (ref
                    .watch(
                        machinePrinterKlippySettingsProvider.selectAs((value) => value.printerData.extruderCount > 1))
                    .valueOrNull!)
                ? DropdownButton(
                    value: activeExtruderIdx,
                    onChanged: klippyCanReceiveCommands
                        ? ref.watch(controlTabControllerProvider.notifier).onExtruderSelected
                        : null,
                    items: List.generate(
                        ref
                            .watch(machinePrinterKlippySettingsProvider
                                .selectAs((value) => value.printerData.extruderCount))
                            .valueOrNull!, (index) {
                      String name = tr('pages.dashboard.control.extrude_card.title');
                      if (index > 0) name += ' $index';
                      return DropdownMenuItem(
                        value: index,
                        child: Text(name),
                      );
                    }))
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: ElevatedButton.icon(
                        onPressed: klippyCanReceiveCommands && canExtrude
                            ? ref.watch(extruderControlCardControllerProvider.notifier).onRetractBtn
                            : null,
                        icon: const Icon(FlutterIcons.minus_ant),
                        label: const Text('pages.dashboard.control.extrude_card.retract').tr(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(5),
                      child: ElevatedButton.icon(
                        onPressed: klippyCanReceiveCommands && canExtrude
                            ? ref.watch(extruderControlCardControllerProvider.notifier).onExtrudeBtn
                            : null,
                        icon: const Icon(FlutterIcons.plus_ant),
                        label: const Text('pages.dashboard.control.extrude_card.extrude').tr(),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${tr('pages.dashboard.control.extrude_card.extrude_len')} [mm]'),
                    ),
                    RangeSelector(
                        selectedIndex: ref.watch(extruderControlCardControllerProvider),
                        onSelected: ref.watch(extruderControlCardControllerProvider.notifier).stepChanged,
                        values: extruderSteps.map((e) => e.toString()).toList()),
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

class GcodeMacroCard extends HookConsumerWidget {
  const GcodeMacroCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    var macroGroups =
        ref.watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.settings.macroGroups)).valueOrNull!;

    var isPrinting = ref
        .watch(machinePrinterKlippySettingsProvider
            .selectAs((value) => value.printerData.print.state == PrintState.printing))
        .valueOrNull!;

    int idx = min(macroGroups.length - 1, max(0, ref.watch(settingServiceProvider).readInt(UtilityKeys.gCodeIndex, 0)));

    var selected = useState(idx);
    var themeData = Theme.of(context);

    var macrosOfGrp = macroGroups[selected.value].macros;
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(FlutterIcons.code_braces_mco),
            title: const Text('pages.dashboard.control.macro_card.title').tr(),
            trailing: (macroGroups.length > 1)
                ? DropdownButton<int>(
                    value: selected.value,
                    onChanged: klippyCanReceiveCommands
                        ? (e) {
                            ref.read(settingServiceProvider).writeInt(UtilityKeys.gCodeIndex, e!);
                            selected.value = e;
                          }
                        : null,
                    items: macroGroups.mapIndex((e, i) {
                      return DropdownMenuItem(
                        value: i,
                        child: Text(e.name),
                      );
                    }).toList())
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Wrap(
              spacing: 5.0,
              children: List<Widget>.generate(
                macrosOfGrp.length,
                (int index) {
                  GCodeMacro macro = macrosOfGrp[index];
                  ConfigGcodeMacro? configGcodeMacro = ref
                      .watch(machinePrinterKlippySettingsProvider
                          .selectAs((data) => data.printerData.configFile.gcodeMacros[macro.name.toLowerCase()]))
                      .valueOrNull;
                  bool disabled = (!klippyCanReceiveCommands || (isPrinting && !macro.showWhilePrinting));
                  return Visibility(
                    visible: ref
                            .watch(machinePrinterKlippySettingsProvider
                                .selectAs((value) => value.printerData.gcodeMacros.contains(macro.name)))
                            .valueOrNull! &&
                        macro.visible,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        minimumSize: const Size(0, 32),
                        foregroundColor: themeData.colorScheme.onPrimary,
                        backgroundColor: themeData.colorScheme.primary,
                        disabledBackgroundColor: themeData.colorScheme.onSurface.withOpacity(0.12),
                        disabledForegroundColor: themeData.colorScheme.onSurface.withOpacity(0.38),
                        textStyle: themeData.chipTheme.labelStyle,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: disabled
                          ? null
                          : () => ref
                              .watch(controlTabControllerProvider.notifier)
                              .onMacroPressed(macro.name, configGcodeMacro),

                      onLongPress: disabled
                          ? null
                          : () => ref.watch(controlTabControllerProvider.notifier).onMacroLongPressed(
                                macro.name,
                              ),
                      child: Text(macro.beautifiedName),

                      // Chip(
                      //   surfaceTintColor: Colors.red,
                      //   label: Text(macro.beautifiedName),
                      //   backgroundColor: disabled
                      //       ? themeData.disabledColor
                      //       : themeData.colorScheme.primary,
                      // ),
                    ),
                  );
                },
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class PinsCard extends ConsumerWidget {
  const PinsCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pinLen = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs(
            (value) => value.printerData.outputPins.values.where((element) => !element.name.startsWith('_')).length))
        .valueOrNull!;

    var ledLen = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs(
            (value) => value.printerData.leds.values.where((element) => !element.name.startsWith('_')).length))
        .valueOrNull!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                FlutterIcons.led_outline_mco,
              ),
              title: Text(plural('pages.dashboard.control.pin_card.title', pinLen + ledLen)),
            ),
            AdaptiveHorizontalScroll(
              pageStorageKey: 'pins',
              children: [
                ...List.generate(pinLen, (index) {
                  var pinProvider = machinePrinterKlippySettingsProvider.selectAs((value) => value
                      .printerData.outputPins.values
                      .where((element) => !element.name.startsWith('_'))
                      .elementAt(index));

                  return _PinTile(pinProvider: pinProvider);
                }),
                ...List.generate(ledLen, (index) {
                  var ledProvider = machinePrinterKlippySettingsProvider.selectAs((value) =>
                      value.printerData.leds.values.where((element) => !element.name.startsWith('_')).elementAt(index));

                  return _Led(
                    ledProvider: ledProvider,
                  );
                })
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _PinTile extends ConsumerWidget {
  const _PinTile({Key? key, required this.pinProvider}) : super(key: key);
  final ProviderListenable<AsyncValue<OutputPin>> pinProvider;

  String pinValue(double v, String locale) {
    if (v > 0) return NumberFormat('0.##', locale).format(v);

    return 'general.off'.tr();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pin = ref.watch(pinProvider).valueOrNull!;
    var pinConfig = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.printerData.configFile.outputs[pin.name]))
        .valueOrNull;
    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    if (pinConfig?.pwm == false) {
      return CardWithSwitch(
          value: pin.value > 0,
          onChanged: (v) => ref.read(controlTabControllerProvider.notifier).onUpdateBinaryPin(pin, v),
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
                  Text(pin.value > 0 ? 'general.on'.tr() : 'general.off'.tr(), style: textTheme.headlineSmall),
                ],
              ),
            );
          });
    }

    return CardWithButton(
        buttonChild: const Text('general.set').tr(),
        onTap: klippyCanReceiveCommands
            ? () => ref.read(controlTabControllerProvider.notifier).onEditPin(pin, pinConfig)
            : null,
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
                Text(pinValue(pin.value * (pinConfig?.scale ?? 1), context.locale.languageCode),
                    style: textTheme.headlineSmall),
              ],
            ),
          );
        });
  }
}

class _Led extends ConsumerWidget {
  const _Led({Key? key, required this.ledProvider}) : super(key: key);
  final ProviderListenable<AsyncValue<Led>> ledProvider;
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
      return Icon(
        Icons.circle,
        size: _iconSize,
        color: c,
      );
    }

    return ShaderMask(
      shaderCallback: (bounds) => SweepGradient(
        colors: colors,
      ).createShader(bounds),
      child: const Icon(
        Icons.circle,
        size: _iconSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Led led = ref.watch(ledProvider).valueOrNull!;
    var ledConfig = ref.watch(machinePrinterKlippySettingsProvider
        .select((value) => value.valueOrNull?.printerData.configFile.leds[led.name.toLowerCase()]));
    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    return CardWithButton(
        buttonChild: const Text('general.set').tr(),
        onTap: klippyCanReceiveCommands
            ? () => ref.read(controlTabControllerProvider.notifier).onEditLed(led, ledConfig)
            : null,
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
                    Text(statusText(led, ledConfig, context.locale.languageCode),
                        style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
                statusWidget(led, ledConfig),
              ],
            ),
          );
        });
  }
}

class MultipliersCard extends HookConsumerWidget {
  const MultipliersCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var inputLocked = useState(true);

    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(FlutterIcons.speedometer_slow_mco),
            title: const Text('pages.dashboard.control.multipl_card.title').tr(),
            trailing: IconButton(
                onPressed: klippyCanReceiveCommands ? () => inputLocked.value = !inputLocked.value : null,
                icon: AnimatedSwitcher(
                  duration: kThemeAnimationDuration,
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: inputLocked.value
                      ? const Icon(FlutterIcons.lock_faw, key: ValueKey('lock'))
                      : const Icon(FlutterIcons.unlock_faw, key: ValueKey('unlock')),
                )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Column(
              children: [
                _SliderOrTextInput(
                  provider: machinePrinterKlippySettingsProvider
                      .select((data) => data.value!.printerData.gCodeMove.speedFactor),
                  prefixText: 'pages.dashboard.general.print_card.speed'.tr(),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref.watch(controlTabControllerProvider.notifier).onEditedSpeedMultiplier
                      : null,
                  addToMax: true,
                ),
                _SliderOrTextInput(
                    provider: machinePrinterKlippySettingsProvider
                        .select((data) => data.value!.printerData.gCodeMove.extrudeFactor),
                    prefixText: 'pages.dashboard.control.multipl_card.flow'.tr(),
                    onChange: klippyCanReceiveCommands && !inputLocked.value
                        ? ref.watch(controlTabControllerProvider.notifier).onEditedFlowMultiplier
                        : null),
                _SliderOrTextInput(
                  provider: machinePrinterKlippySettingsProvider
                      .select((data) => data.value!.printerData.extruder.pressureAdvance),
                  prefixText: 'pages.dashboard.control.multipl_card.press_adv'.tr(),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref.watch(controlTabControllerProvider.notifier).onEditedPressureAdvanced
                      : null,
                  numberFormat: NumberFormat('0.##### mm/s', context.locale.languageCode),
                  unit: 'mm/s',
                ),
                _SliderOrTextInput(
                  provider: machinePrinterKlippySettingsProvider
                      .select((data) => data.value!.printerData.extruder.smoothTime),
                  prefixText: 'pages.dashboard.control.multipl_card.smooth_time'.tr(),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref.watch(controlTabControllerProvider.notifier).onEditedSmoothTime
                      : null,
                  numberFormat: NumberFormat('0.### s', context.locale.languageCode),
                  maxValue: 0.2,
                  unit: 's',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LimitsCard extends HookConsumerWidget {
  const LimitsCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var inputLocked = useState(true);

    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('pages.dashboard.control.limit_card.title').tr(),
            trailing: IconButton(
                onPressed: (klippyCanReceiveCommands) ? () => inputLocked.value = !inputLocked.value : null,
                icon: AnimatedSwitcher(
                  duration: kThemeAnimationDuration,
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: inputLocked.value
                      ? const Icon(FlutterIcons.lock_faw, key: ValueKey('lock'))
                      : const Icon(FlutterIcons.unlock_faw, key: ValueKey('unlock')),
                )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Column(
              children: [
                _SliderOrTextInput(
                  provider: machinePrinterKlippySettingsProvider
                      .select((data) => data.value!.printerData.toolhead.maxVelocity),
                  prefixText: tr('pages.dashboard.control.limit_card.velocity'),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref.watch(controlTabControllerProvider.notifier).onEditedMaxVelocity
                      : null,
                  numberFormat: NumberFormat('0 mm/s', context.locale.languageCode),
                  unit: 'mm/s',
                  maxValue: 500,
                ),
                _SliderOrTextInput(
                  provider:
                      machinePrinterKlippySettingsProvider.select((data) => data.value!.printerData.toolhead.maxAccel),
                  prefixText: tr('pages.dashboard.control.limit_card.accel'),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref.watch(controlTabControllerProvider.notifier).onEditedMaxAccel
                      : null,
                  numberFormat: NumberFormat('0 mm/s²', context.locale.languageCode),
                  unit: 'mm/s²',
                  maxValue: 5000,
                ),
                _SliderOrTextInput(
                  provider: machinePrinterKlippySettingsProvider
                      .select((data) => data.value!.printerData.toolhead.squareCornerVelocity),
                  prefixText: tr('pages.dashboard.control.limit_card.sq_corn_vel'),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref.watch(controlTabControllerProvider.notifier).onEditedMaxSquareCornerVelocity
                      : null,
                  numberFormat: NumberFormat('0.# mm/s', context.locale.languageCode),
                  unit: 'mm/s',
                  maxValue: 8,
                ),
                _SliderOrTextInput(
                  provider: machinePrinterKlippySettingsProvider
                      .select((data) => data.value!.printerData.toolhead.maxAccelToDecel),
                  prefixText: tr('pages.dashboard.control.limit_card.accel_to_decel'),
                  onChange: klippyCanReceiveCommands && !inputLocked.value
                      ? ref.watch(controlTabControllerProvider.notifier).onEditedMaxAccelToDecel
                      : null,
                  numberFormat: NumberFormat('0 mm/s²', context.locale.languageCode),
                  unit: 'mm/s²',
                  maxValue: 3500,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderOrTextInput extends ConsumerStatefulWidget {
  final ValueChanged<double>? onChange;
  final NumberFormat numberFormat;
  final String prefixText;
  final ProviderListenable<double> provider;
  final double maxValue;
  final double minValue;
  final String? unit;
  final bool addToMax;

  _SliderOrTextInput({
    Key? key,
    required this.provider,
    required this.prefixText,
    required this.onChange,
    NumberFormat? numberFormat,
    this.maxValue = 2,
    this.minValue = 0,
    this.addToMax = false,
    this.unit,
  })  : numberFormat = numberFormat ?? NumberFormat('0%'),
        super(key: key);

  @override
  _SliderOrTextInputState createState() => _SliderOrTextInputState();
}

class _SliderOrTextInputState extends ConsumerState<_SliderOrTextInput> {
  late double sliderPos;
  late bool focusRequested;
  late bool inputValid;
  late TextEditingController textEditingController;
  late FocusNode focusNode;
  late bool isTextFieldFocused;
  late CrossFadeState fadeState;
  late double lastSubmittedValue;

  late double stepsToAdd;
  late double maxValue;

  NumberFormat get _numberFormat => widget.numberFormat;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    focusNode = FocusNode();
    textEditingController = TextEditingController();
    maxValue = widget.maxValue;
    stepsToAdd = (maxValue - widget.minValue) / 2;
    // Actual States

    double initValue = ref.read(widget.provider);
    lastSubmittedValue = initValue;
    sliderPos = initValue;
    _updateTextController(initValue);

    isTextFieldFocused = false;
    fadeState = CrossFadeState.showFirst;

    // Helper States
    inputValid = true;

    // Setup listener
    focusNode.addListener(() {
      setState(() {
        if (isTextFieldFocused != focusNode.hasFocus) _onFocusChanged();
        isTextFieldFocused = focusNode.hasFocus;
      });
    });

    textEditingController.addListener(() {
      var text = textEditingController.text;

      setState(() {
        inputValid = text.isNotEmpty && RegExp(r'^\d+([.,])?\d*?$').hasMatch(text);
      });
    });
  }

  @override
  void dispose() {
    textEditingController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(widget.provider, (previous, next) {
      if (next == lastSubmittedValue) return;
      lastSubmittedValue = next;
      sliderPos = next;
      _updateTextController(next);
    });

    return Row(
      children: [
        Flexible(
          child: AnimatedCrossFade(
            firstChild: InputDecorator(
              decoration: InputDecoration(
                label: Text('${widget.prefixText}: ${_numberFormat.format(sliderPos)}'),
                isCollapsed: true,
                border: InputBorder.none,
              ),
              child: Slider(
                value: min(maxValue, sliderPos),
                onChanged: widget.onChange != null ? _onSliderChanged : null,
                onChangeEnd: widget.onChange != null ? _onSliderDone : null,
                max: maxValue,
                min: widget.minValue,
              ),
            ),
            secondChild: TextField(
              decoration: InputDecoration(
                prefixText: '${widget.prefixText}:',
                border: InputBorder.none,
                suffix: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(widget.unit ?? '%'),
                ),
                errorText: !inputValid ? FormBuilderLocalizations.current.numericErrorText : null,
              ),
              enabled: widget.onChange != null,
              onSubmitted: _submitTextField,
              focusNode: focusNode,
              controller: textEditingController,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
            ),
            duration: kThemeAnimationDuration,
            crossFadeState: fadeState,
          ),
        ),
        AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          child: fadeState == CrossFadeState.showSecond && isTextFieldFocused
              ? IconButton(
                  key: const ValueKey('checkmark'),
                  icon: const Icon(Icons.check),
                  onPressed: inputValid ? _onCheckmarkClick : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 33, minHeight: 33),
                )
              : IconButton(
                  key: const ValueKey('edit'),
                  icon: const Icon(Icons.edit),
                  onPressed: inputValid && widget.onChange != null ? _toggle : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 33, minHeight: 33),
                ),
        ),
      ],
    );
  }

  _onSliderChanged(double v) {
    setState(() {
      sliderPos = v;
    });
  }

  _onSliderDone(double v) {
    _submit(v);
    _onSliderChanged(v);
    if (widget.addToMax && v == maxValue) {
      setState(() {
        maxValue += stepsToAdd;
      });
    }
  }

  _submitTextField(String value) {
    if (!inputValid) return;

    double perc = _numberFormat.parse(textEditingController.text).toDouble();
    _submit(perc);
  }

  _onCheckmarkClick() {
    focusNode.unfocus();
    _submitTextField(textEditingController.text);
  }

  _toggle() {
    setState(() {
      if (fadeState == CrossFadeState.showFirst) {
        _updateTextController(sliderPos);
        fadeState = CrossFadeState.showSecond;
        focusNode.requestFocus();
      } else {
        sliderPos = _numberFormat.parse(textEditingController.text).toDouble();
        fadeState = CrossFadeState.showFirst;
        focusNode.unfocus();
      }
    });
  }

  _updateTextController(double value) {
    textEditingController.text = _numberFormat.format(value).replaceAll(RegExp(r'[^0-9.,]'), '');
  }

  _onFocusChanged() {
    _submitTextField(textEditingController.text);
  }

  _submit(double value) {
    if (widget.onChange == null || lastSubmittedValue == value) return;
    lastSubmittedValue = value;
    widget.onChange!(value);
  }
}
