/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/config/led/config_dumb_led.dart';
import 'package:common/data/dto/config/led/config_led.dart';
import 'package:common/data/dto/machine/fans/generic_fan.dart';
import 'package:common/data/dto/machine/fans/named_fan.dart';
import 'package:common/data/dto/machine/leds/addressable_led.dart';
import 'package:common/data/dto/machine/leds/dumb_led.dart';
import 'package:common/data/dto/machine/leds/led.dart';
import 'package:common/data/dto/machine/output_pin.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/card_with_switch.dart';
import 'package:mobileraker/ui/components/power_api_panel.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';
import 'package:mobileraker/ui/screens/dashboard/components/control_extruder_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/macro_group_card.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/control_tab_controller.dart';
import 'package:mobileraker/util/extensions/pixel_extension.dart';
import 'package:progress_indicators/progress_indicators.dart';

import '../../../components/horizontal_scroll_indicator.dart';
import '../components/firmware_retraction_card.dart';
import '../components/limits_card.dart';
import '../components/multipliers_card.dart';

class ControlTab extends ConsumerWidget {
  const ControlTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var settingService = ref.watch(settingServiceProvider);

    return ref.watch(machinePrinterKlippySettingsProvider.selectAs((data) => data.machine.uuid)).when(
          data: (data) {
            var groupSliders = settingService.readBool(AppSettingKeys.groupSliders, true);
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
                    MacroGroupCard(machineUUID: data),
                  if (ref
                          .watch(machinePrinterKlippySettingsProvider
                              .selectAs((value) => value.printerData.print.state != PrintState.printing))
                          .valueOrNull ??
                      false)
                    ControlExtruderCard(machineUUID: data),
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
                  if (groupSliders) const _MiscCard(),
                  if (!groupSliders) ...[
                    MultipliersCard(machineUUID: data),
                    LimitsCard(machineUUID: data),
                    if (ref
                            .watch(machinePrinterKlippySettingsProvider
                                .selectAs((data) => data.printerData.firmwareRetraction != null))
                            .valueOrNull ==
                        true)
                      FirmwareRetractionCard(machineUUID: data),
                  ],
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
                  const SizedBox(height: 22),
                  const Text(
                    'Error while trying to fetch printer...\nPlease provide the error to the project owner\nvia GitHub!',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    // onPressed: model.showPrinterFetchingErrorDialog,
                    onPressed: () => ref.read(dialogServiceProvider).show(
                          DialogRequest(
                            type: CommonDialogs.stacktrace,
                            title: e.runtimeType.toString(),
                            body: 'Exception:\n $e\n\n$s',
                          ),
                        ),
                    child: const Text('Show Error'),
                  ),
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
                const SizedBox(height: 30),
                FadingText('Fetching printer data'),
                // Text('Fetching printer ...')
              ],
            ),
          ),
        );
  }
}

class FansCard extends ConsumerWidget {
  const FansCard({Key? key}) : super(key: key);

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
              leading: const Icon(FlutterIcons.fan_mco),
              title: const Text('pages.dashboard.control.fan_card.title').plural(fanLen),
            ),
            AdaptiveHorizontalScroll(pageStorageKey: 'fans', children: [
              if (ref
                      .watch(machinePrinterKlippySettingsProvider.selectAs(
                        (data) => data.printerData.isPrintFanAvailable,
                      ))
                      .valueOrNull ==
                  true)
                const _PrintFan(),
              ...List.generate(fanLen, (index) {
                var fanProvider = machinePrinterKlippySettingsProvider.selectAs(
                  (value) =>
                      value.printerData.fans.values.where((element) => !element.name.startsWith('_')).elementAt(index),
                );

                return _Fan(fanProvider: fanProvider);
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
                  Text(
                    fanSpeed,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              speed > 0 ? const SpinningFan(size: icoSize) : const Icon(FlutterIcons.fan_off_mco, size: icoSize),
            ],
          ),
        );
      },
    );
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

class PinsCard extends ConsumerWidget {
  const PinsCard({Key? key}) : super(key: key);

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
              leading: const Icon(FlutterIcons.led_outline_mco),
              title: Text(plural(
                'pages.dashboard.control.pin_card.title',
                pinLen + ledLen,
              )),
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

                  return _Led(ledProvider: ledProvider);
                }),
              ],
            ),
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
        .watch(machinePrinterKlippySettingsProvider.selectAs(
          (value) => value.printerData.configFile.outputs[pin.name],
        ))
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
              Text(
                pinValue(
                  pin.value * (pinConfig?.scale ?? 1),
                  context.locale.languageCode,
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
      return Icon(Icons.circle, size: _iconSize, color: c);
    }

    return ShaderMask(
      shaderCallback: (bounds) => SweepGradient(colors: colors).createShader(bounds),
      child: const Icon(Icons.circle, size: _iconSize),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Led led = ref.watch(ledProvider).valueOrNull!;
    var ledConfig = ref.watch(machinePrinterKlippySettingsProvider.select(
      (value) => value.valueOrNull?.printerData.configFile.leds[led.name.toLowerCase()],
    ));
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
                  Text(
                    statusText(led, ledConfig, context.locale.languageCode),
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

class _MiscCard extends HookConsumerWidget {
  const _MiscCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pageController = usePageController();

    var macineUUID = ref.watch(machinePrinterKlippySettingsProvider.selectAs((data) => data.machine.uuid)).value!;
    var childs = [
      MultipliersSlidersOrTexts(machineUUID: macineUUID),
      LimitsSlidersOrTexts(machineUUID: macineUUID),
      if (ref
              .watch(machinePrinterKlippySettingsProvider.selectAs(
                (data) => data.printerData.firmwareRetraction != null,
              ))
              .valueOrNull ==
          true)
        FirmwareRetractionSlidersOrTexts(machineUUID: macineUUID),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Column(
          children: [
            ExpandablePageView(
              key: const PageStorageKey<String>('sliders_and_text'),
              estimatedPageSize: 250,
              controller: pageController,
              children: childs,
            ),
            HorizontalScrollIndicator(
              steps: childs.length,
              controller: pageController,
              childsPerScreen: 1,
            ),
          ],
        ),
      ),
    );
  }
}
