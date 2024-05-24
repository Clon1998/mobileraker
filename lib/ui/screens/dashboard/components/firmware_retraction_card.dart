/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: prefer-single-widget-per-file

import 'package:common/data/dto/machine/firmware_retraction.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/slider_or_text_input_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import 'slider_or_text_input.dart';

part 'firmware_retraction_card.freezed.dart';
part 'firmware_retraction_card.g.dart';

class FirmwareRetractionCard extends HookConsumerWidget {
  const FirmwareRetractionCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview();
  }

  final String machineUUID;

  CompositeKey get _hadFwRetract => CompositeKey.keyWithString(UiKeys.hadFirmwareRetraction, machineUUID);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    var hadFwRetract = ref.read(boolSettingProvider(_hadFwRetract));

    logger.i('Rebuilding FirmwareRetractionCard for $machineUUID');

    return AsyncGuard(
      animate: true,
      debugLabel: 'FirmwareRetractionCard-$machineUUID',
      toGuard: _firmwareRetractionCardControllerProvider(machineUUID).selectAs((data) => data.showCard),
      childOnLoading: hadFwRetract
          ? Card(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: FirmwareRetractionSlidersOrTexts(machineUUID: machineUUID),
              ),
            )
          : null,
      childOnData: Card(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: _CardBody(machineUUID: machineUUID),
        ),
      ),
    );
  }
}

class _Preview extends HookWidget {
  static const String _machineUUID = 'preview';

  const _Preview({super.key, this.isCard = true});

  final bool isCard;

  @override
  Widget build(BuildContext context) {
    useAutomaticKeepAlive();
    return ProviderScope(
      overrides: [
        _firmwareRetractionCardControllerProvider(_machineUUID)
            .overrideWith(_FirmwareRetractionCardPreviewController.new),
      ],
      child: isCard
          ? const FirmwareRetractionCard(machineUUID: _machineUUID)
          : const FirmwareRetractionSlidersOrTexts(machineUUID: _machineUUID),
    );
  }
}

class FirmwareRetractionSlidersOrTexts extends HookConsumerWidget {
  const FirmwareRetractionSlidersOrTexts({
    super.key,
    required this.machineUUID,
  });

  static Widget preview() {
    return const _Preview(isCard: false);
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('Rebuilding FirmwareRetractionSlidersOrTexts for $machineUUID');

    return AsyncGuard(
      debugLabel: 'FirmwareRetractionSlidersOrTexts-$machineUUID',
      toGuard: _firmwareRetractionCardControllerProvider(machineUUID).selectAs((data) => true),
      childOnLoading: const _FirmwareRetractionSlidersOrTextsLoading(),
      childOnData: _CardBody(machineUUID: machineUUID),
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

class _CardBody extends HookConsumerWidget {
  const _CardBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('Building FirmwareRetractionBody for $machineUUID');
    var inputLocked = useState(true);
    var controller = ref.watch(_firmwareRetractionCardControllerProvider(machineUUID).notifier);

    var klippyCanReceiveCommands = ref.watch(_firmwareRetractionCardControllerProvider(machineUUID)
        .selectRequireValue((data) => data.klippyCanReceiveCommands));

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
                provider: _firmwareRetractionCardControllerProvider(machineUUID)
                    .selectRequireValue((data) => data.firmwareRetraction!.retractLength),
                prefixText: tr('pages.dashboard.control.fw_retraction_card.retract_length'),
                onChange: canEdit ? controller.onEditRetractLength : null,
                numberFormat: NumberFormat('0.0# mm', context.locale.toStringWithSeparator()),
                unit: 'mm',
                maxValue: 1,
                addToMax: true,
              ),
              SliderOrTextInput(
                provider: _firmwareRetractionCardControllerProvider(machineUUID)
                    .selectRequireValue((data) => data.firmwareRetraction!.unretractExtraLength),
                prefixText: tr('pages.dashboard.control.fw_retraction_card.extra_unretract_length'),
                onChange: canEdit ? controller.onEditUnretractLength : null,
                numberFormat: NumberFormat('0.0# mm', context.locale.toStringWithSeparator()),
                unit: 'mm',
                maxValue: 1,
                addToMax: true,
              ),
              SliderOrTextInput(
                provider: _firmwareRetractionCardControllerProvider(machineUUID)
                    .selectRequireValue((data) => data.firmwareRetraction!.retractSpeed),
                prefixText: tr('pages.dashboard.control.fw_retraction_card.retract_speed'),
                onChange: canEdit ? controller.onEditRetractSpeed : null,
                numberFormat: NumberFormat('0 mm/s', context.locale.toStringWithSeparator()),
                unit: 'mm/s',
                maxValue: 70,
                addToMax: true,
              ),
              SliderOrTextInput(
                provider: _firmwareRetractionCardControllerProvider(machineUUID)
                    .selectRequireValue((data) => data.firmwareRetraction!.unretractSpeed),
                prefixText: tr('pages.dashboard.control.fw_retraction_card.unretract_speed'),
                onChange: canEdit ? controller.onEditUnretractSpeed : null,
                numberFormat: NumberFormat('0 mm/s', context.locale.toStringWithSeparator()),
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
class _FirmwareRetractionCardController extends _$FirmwareRetractionCardController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  CompositeKey get _hadFwRetract => CompositeKey.keyWithString(UiKeys.hadFirmwareRetraction, machineUUID);

  bool? _wroteValue;

  @override
  Future<_Model> build(String machineUUID) async {
    ref.keepAliveFor();
    // await Future.delayed(const Duration(milliseconds: 5000));

    var klippyCanReceiveF =
        ref.watch(klipperProvider(machineUUID).selectAsync((data) => data.klippyCanReceiveCommands));
    var firmwareRetractionF = ref.watch(printerProvider(machineUUID).selectAsync((data) => data.firmwareRetraction));

    var [a, b] = await Future.wait([klippyCanReceiveF, firmwareRetractionF]);

    var fwRetract = b as FirmwareRetraction?;

    var tmp = fwRetract != null;
    if (_wroteValue != tmp) {
      _wroteValue = tmp;
      _settingService.writeBool(_hadFwRetract, tmp);
    }

    return _Model(
      klippyCanReceiveCommands: a as bool,
      firmwareRetraction: fwRetract,
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

class _FirmwareRetractionCardPreviewController extends _FirmwareRetractionCardController {
  @override
  Future<_Model> build(String machineUUID) {
    const model = _Model(
      klippyCanReceiveCommands: true,
      firmwareRetraction: FirmwareRetraction(
        retractLength: 0.7,
        unretractExtraLength: 0.32,
        retractSpeed: 15,
        unretractSpeed: 22,
      ),
    );
    state = const AsyncValue.data(model);
    return Future.value(model);
  }

  @override
  onEditRetractLength(double value) {
    // do nothing in preview
  }

  @override
  onEditUnretractLength(double value) {
    // do nothing in preview
  }

  @override
  onEditRetractSpeed(double value) {
    // do nothing in preview
  }

  @override
  onEditUnretractSpeed(double value) {
    // do nothing in preview
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required FirmwareRetraction? firmwareRetraction,
  }) = __Model;

  bool get showCard => firmwareRetraction != null;
}
