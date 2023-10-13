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

part 'limits_card.g.dart';

class LimitsCard extends StatelessWidget {
  const LimitsCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => const Card(
          child: Padding(
        padding: EdgeInsets.only(bottom: 15),
        child: LimitsSlidersOrTexts(),
      ));
}

class LimitsSlidersOrTexts extends HookConsumerWidget {
  const LimitsSlidersOrTexts({super.key});

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
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              SliderOrTextInput(
                provider:
                    machinePrinterKlippySettingsProvider.select((data) => data.value!.printerData.toolhead.maxVelocity),
                prefixText: tr('pages.dashboard.control.limit_card.velocity'),
                onChange: klippyCanReceiveCommands && !inputLocked.value ? controller.onEditedMaxVelocity : null,
                numberFormat: NumberFormat('0 mm/s', context.locale.languageCode),
                unit: 'mm/s',
                maxValue: 500,
              ),
              SliderOrTextInput(
                provider:
                    machinePrinterKlippySettingsProvider.select((data) => data.value!.printerData.toolhead.maxAccel),
                prefixText: tr('pages.dashboard.control.limit_card.accel'),
                onChange: klippyCanReceiveCommands && !inputLocked.value ? controller.onEditedMaxAccel : null,
                numberFormat: NumberFormat('0 mm/s²', context.locale.languageCode),
                unit: 'mm/s²',
                maxValue: 5000,
              ),
              SliderOrTextInput(
                provider: machinePrinterKlippySettingsProvider
                    .select((data) => data.value!.printerData.toolhead.squareCornerVelocity),
                prefixText: tr('pages.dashboard.control.limit_card.sq_corn_vel'),
                onChange:
                    klippyCanReceiveCommands && !inputLocked.value ? controller.onEditedMaxSquareCornerVelocity : null,
                numberFormat: NumberFormat('0.# mm/s', context.locale.languageCode),
                unit: 'mm/s',
                maxValue: 8,
              ),
              SliderOrTextInput(
                provider: machinePrinterKlippySettingsProvider
                    .select((data) => data.value!.printerData.toolhead.maxAccelToDecel),
                prefixText: tr('pages.dashboard.control.limit_card.accel_to_decel'),
                onChange: klippyCanReceiveCommands && !inputLocked.value ? controller.onEditedMaxAccelToDecel : null,
                numberFormat: NumberFormat('0 mm/s²', context.locale.languageCode),
                unit: 'mm/s²',
                maxValue: 3500,
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

  onEditedMaxVelocity(double value) {
    _printerService.setVelocityLimit(value.toInt());
  }

  onEditedMaxAccel(double value) {
    _printerService.setAccelerationLimit(value.toInt());
  }

  onEditedMaxSquareCornerVelocity(double value) {
    _printerService.setSquareCornerVelocityLimit(value);
  }

  onEditedMaxAccelToDecel(double value) {
    _printerService.setAccelToDecel(value.toInt());
  }
}
