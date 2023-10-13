/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../dashboard_controller.dart';
import 'SliderOrTextInput.dart';

part 'multipliers_card.g.dart';

class MultipliersCard extends StatelessWidget {
  const MultipliersCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.only(bottom: 15),
        child: MultipliersSlidersOrTexts(),
      ),
    );
  }
}

class MultipliersSlidersOrTexts extends HookConsumerWidget {
  const MultipliersSlidersOrTexts({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var inputLocked = useState(true);

    var controller = ref.watch(_cardControllerProvider.notifier);

    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    return Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              SliderOrTextInput(
                provider: machinePrinterKlippySettingsProvider
                    .select((data) => data.value!.printerData.gCodeMove.speedFactor),
                prefixText: 'pages.dashboard.general.print_card.speed'.tr(),
                onChange: klippyCanReceiveCommands && !inputLocked.value ? controller.onEditedSpeedMultiplier : null,
                addToMax: true,
              ),
              SliderOrTextInput(
                  provider: machinePrinterKlippySettingsProvider
                      .select((data) => data.value!.printerData.gCodeMove.extrudeFactor),
                  prefixText: 'pages.dashboard.control.multipl_card.flow'.tr(),
                  onChange: klippyCanReceiveCommands && !inputLocked.value ? controller.onEditedFlowMultiplier : null),
              SliderOrTextInput(
                provider: machinePrinterKlippySettingsProvider
                    .select((data) => data.value!.printerData.extruder.pressureAdvance),
                prefixText: 'pages.dashboard.control.multipl_card.press_adv'.tr(),
                onChange: klippyCanReceiveCommands && !inputLocked.value ? controller.onEditedPressureAdvanced : null,
                numberFormat: NumberFormat('0.##### mm/s', context.locale.languageCode),
                unit: 'mm/s',
              ),
              SliderOrTextInput(
                provider:
                    machinePrinterKlippySettingsProvider.select((data) => data.value!.printerData.extruder.smoothTime),
                prefixText: 'pages.dashboard.control.multipl_card.smooth_time'.tr(),
                onChange: klippyCanReceiveCommands && !inputLocked.value ? controller.onEditedSmoothTime : null,
                numberFormat: NumberFormat('0.### s', context.locale.languageCode),
                maxValue: 0.2,
                unit: 's',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

@riverpod
class _CardController extends _$CardController {
  @override
  void build() {}

  PrinterService get _printerService => ref.read(printerServiceSelectedProvider);

  onEditedSpeedMultiplier(double value) {
    _printerService.speedMultiplier((value * 100).toInt());
  }

  onEditedFlowMultiplier(double value) {
    _printerService.flowMultiplier((value * 100).toInt());
  }

  onEditedPressureAdvanced(double value) {
    _printerService.pressureAdvance(value);
  }

  onEditedSmoothTime(double value) {
    _printerService.smoothTime(value);
  }
}
