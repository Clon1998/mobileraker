/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/slider_or_text_input_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import 'slider_or_text_input.dart';

part 'firmware_retraction_card.freezed.dart';
part 'firmware_retraction_card.g.dart';

class FirmwareRetractionCard extends ConsumerWidget {
  const FirmwareRetractionCard({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: FirmwareRetractionSlidersOrTexts(machineUUID: machineUUID),
      ),
    );
  }
}

class _FirmwareRetractionSlidersOrTextsLoading extends StatelessWidget {
  const _FirmwareRetractionSlidersOrTextsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: Colors.grey,
      highlightColor: themeData.colorScheme.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CardTitleSkeleton.trailingIcon(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderOrTextInputSkeleton(value: 0.7),
                SliderOrTextInputSkeleton(value: 0.32),
                SliderOrTextInputSkeleton(value: 0.6),
                SliderOrTextInputSkeleton(value: 0.88),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FirmwareRetractionSlidersOrTexts extends HookConsumerWidget {
  const FirmwareRetractionSlidersOrTexts({
    Key? key,
    required this.machineUUID,
  }) : super(key: key);

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var showLoading =
        ref.watch(_controllerProvider(machineUUID).select((value) => value.isLoading && !value.isReloading));

    if (showLoading) {
      return const _FirmwareRetractionSlidersOrTextsLoading();
    }

    var inputLocked = useState(true);

    var controller = ref.watch(_controllerProvider(machineUUID).notifier);
    var klippyCanReceiveCommands =
        ref.watch(_controllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands)).requireValue;

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
                  : const Icon(
                      FlutterIcons.unlock_faw,
                      key: ValueKey('unlock'),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              SliderOrTextInput(
                provider: _controllerProvider(machineUUID).select((data) => data.requireValue.retractLength),
                prefixText: tr(
                  'pages.dashboard.control.fw_retraction_card.retract_length',
                ),
                onChange: canEdit ? controller.onEditRetractLength : null,
                numberFormat: NumberFormat('0.0# mm', context.locale.languageCode),
                unit: 'mm',
                maxValue: 1,
                addToMax: true,
              ),
              SliderOrTextInput(
                provider: _controllerProvider(machineUUID).select((data) => data.requireValue.unretractExtraLength),
                prefixText: tr(
                  'pages.dashboard.control.fw_retraction_card.extra_unretract_length',
                ),
                onChange: canEdit ? controller.onEditUnretractLength : null,
                numberFormat: NumberFormat('0.0# mm', context.locale.languageCode),
                unit: 'mm',
                maxValue: 1,
                addToMax: true,
              ),
              SliderOrTextInput(
                provider: _controllerProvider(machineUUID).select((data) => data.requireValue.retractSpeed),
                prefixText: tr(
                  'pages.dashboard.control.fw_retraction_card.retract_speed',
                ),
                onChange: canEdit ? controller.onEditRetractSpeed : null,
                numberFormat: NumberFormat('0 mm/s', context.locale.languageCode),
                unit: 'mm/s',
                maxValue: 70,
                addToMax: true,
              ),
              SliderOrTextInput(
                provider: _controllerProvider(machineUUID).select((data) => data.requireValue.unretractSpeed),
                prefixText: tr(
                  'pages.dashboard.control.fw_retraction_card.unretract_speed',
                ),
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
class _Controller extends _$Controller {
  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.keepAliveFor();

    var printerProviderr = printerProvider(machineUUID);
    var klipperProviderr = klipperProvider(machineUUID);

    var klippyCanReceiveCommands = ref.watchAsSubject(
      klipperProviderr.selectAs((value) => value.klippyCanReceiveCommands),
    );
    var firmwareRetraction = ref.watchAsSubject(
      printerProviderr.selectAs((value) => value.firmwareRetraction!),
    );

    yield* Rx.combineLatest2(
      klippyCanReceiveCommands,
      firmwareRetraction,
      (a, b) => _Model(
        klippyCanReceiveCommands: a,
        retractLength: b.retractLength,
        unretractExtraLength: b.unretractExtraLength,
        retractSpeed: b.retractSpeed,
        unretractSpeed: b.unretractSpeed,
      ),
    );
  }

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

@freezed
class _Model with _$Model {
  const factory _Model({
    required bool klippyCanReceiveCommands,
    required double retractLength,
    required double unretractExtraLength,
    required double retractSpeed,
    required double unretractSpeed,
  }) = __Model;
}
