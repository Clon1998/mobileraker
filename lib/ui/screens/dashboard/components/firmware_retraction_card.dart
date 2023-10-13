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

part 'firmware_retraction_card.g.dart';

class FirmwareRetractionCard extends StatelessWidget {
  const FirmwareRetractionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.only(bottom: 15),
        child: FirmwareRetractionSlidersOrTexts(),
      ),
    );
  }
}

class FirmwareRetractionSlidersOrTexts extends HookConsumerWidget {
  const FirmwareRetractionSlidersOrTexts({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var inputLocked = useState(true);

    var controller = ref.watch(_cardControllerProvider.notifier);

    var klippyCanReceiveCommands = ref
        .watch(machinePrinterKlippySettingsProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    var canEdit = klippyCanReceiveCommands && !inputLocked.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.shuffle),
          title: const Text('pages.dashboard.control.fw_retraction_card.title').tr(),
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
                provider: machinePrinterKlippySettingsProvider
                    .select((data) => data.value!.printerData.firmwareRetraction!.retractLength),
                prefixText: tr('pages.dashboard.control.fw_retraction_card.retract_length'),
                onChange: canEdit ? controller.onEditRetractLength : null,
                numberFormat: NumberFormat('0.0# mm', context.locale.languageCode),
                unit: 'mm',
                maxValue: 1,
                addToMax: true,
              ),
              SliderOrTextInput(
                provider: machinePrinterKlippySettingsProvider
                    .select((data) => data.value!.printerData.firmwareRetraction!.unretractExtraLength),
                prefixText: tr('pages.dashboard.control.fw_retraction_card.extra_unretract_length'),
                onChange: canEdit ? controller.onEditUnretractLength : null,
                numberFormat: NumberFormat('0.0# mm', context.locale.languageCode),
                unit: 'mm',
                maxValue: 1,
                addToMax: true,
              ),
              SliderOrTextInput(
                provider: machinePrinterKlippySettingsProvider
                    .select((data) => data.value!.printerData.firmwareRetraction!.retractSpeed),
                prefixText: tr('pages.dashboard.control.fw_retraction_card.retract_speed'),
                onChange: canEdit ? controller.onEditRetractSpeed : null,
                numberFormat: NumberFormat('0 mm/s', context.locale.languageCode),
                unit: 'mm/s',
                maxValue: 70,
                addToMax: true,
              ),
              SliderOrTextInput(
                provider: machinePrinterKlippySettingsProvider
                    .select((data) => data.value!.printerData.firmwareRetraction!.unretractSpeed),
                prefixText: tr('pages.dashboard.control.fw_retraction_card.unretract_speed'),
                onChange: canEdit ? controller.onEditUnretractSpeed : null,
                numberFormat: NumberFormat('0 mm/s', context.locale.languageCode),
                unit: 'mm/s',
                maxValue: 70,
                addToMax: true,
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

  onEditRetractLength(double value) {
    _printerService.firmwareRetraction(retractLength: value);
  }

  onEditUnretractLength(double value) {
    _printerService.firmwareRetraction(unretractExtraLength: value);
  }

  onEditRetractSpeed(double value) {
    _printerService.firmwareRetraction(retractSpeed: value);
  }

  onEditUnretractSpeed(double value) {
    _printerService.firmwareRetraction(unretractSpeed: value);
  }
}
