/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: prefer-single-widget-per-file

import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/slider_or_text_input_skeleton.dart';
import 'package:common/ui/components/slider_or_text_input.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

part 'limits_card.freezed.dart';
part 'limits_card.g.dart';

class LimitsCard extends HookWidget {
  const LimitsCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview();
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context) {
    useAutomaticKeepAlive();

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: LimitsSlidersOrTexts(machineUUID: machineUUID),
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
      overrides: [_controllerProvider(_machineUUID).overrideWith(_PreviewController.new)],
      child: isCard
          ? const LimitsCard(machineUUID: _machineUUID)
          : const LimitsSlidersOrTexts(machineUUID: _machineUUID),
    );
  }
}

class _LimitsSlidersOrTextsLoading extends StatelessWidget {
  const _LimitsSlidersOrTextsLoading({super.key});

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
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderOrTextInputSkeleton(value: 0.4),
                SliderOrTextInputSkeleton(value: 0.8),
                SliderOrTextInputSkeleton(value: 0.7),
                SliderOrTextInputSkeleton(value: 0.65),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LimitsSlidersOrTexts extends HookConsumerWidget {
  const LimitsSlidersOrTexts({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview(isCard: false);
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncGuard(
      animate: true,
      debugLabel: 'LimitsSlidersOrTexts-$machineUUID',
      toGuard: _controllerProvider(machineUUID).selectAs((data) => true),
      childOnLoading: const _LimitsSlidersOrTextsLoading(),
      childOnData: _Body(machineUUID: machineUUID),
    );
  }
}

class _Body extends HookConsumerWidget {
  const _Body({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Building LimitsSlidersOrTextsBody for $machineUUID');

    var inputLocked = useState(true);
    var controller = ref.watch(_controllerProvider(machineUUID).notifier);

    var klippyCanReceiveCommands = ref.watch(
      _controllerProvider(machineUUID).selectRequireValue((data) => data.klippyCanReceiveCommands),
    );

    var canEdit = klippyCanReceiveCommands && !inputLocked.value;

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
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              SliderOrTextInput(
                value: ref.watch(_controllerProvider(machineUUID).selectRequireValue((data) => data.maxVelocity)),
                prefixText: tr('pages.dashboard.control.limit_card.velocity'),
                onChange: canEdit ? controller.onEditedMaxVelocity : null,
                numberFormat: NumberFormat('0 mm/s', context.locale.toStringWithSeparator()),
                unit: 'mm/s',
                maxValue: 500,
              ),
              SliderOrTextInput(
                value: ref.watch(_controllerProvider(machineUUID).selectRequireValue((data) => data.maxAccel)),
                prefixText: tr('pages.dashboard.control.limit_card.accel'),
                onChange: canEdit ? controller.onEditedMaxAccel : null,
                numberFormat: NumberFormat('0 mm/s²', context.locale.toStringWithSeparator()),
                unit: 'mm/s²',
                maxValue: 5000,
              ),
              SliderOrTextInput(
                value: ref.watch(
                  _controllerProvider(machineUUID).selectRequireValue((data) => data.squareCornerVelocity),
                ),
                prefixText: tr('pages.dashboard.control.limit_card.sq_corn_vel'),
                onChange: canEdit ? controller.onEditedMaxSquareCornerVelocity : null,
                numberFormat: NumberFormat('0.# mm/s', context.locale.toStringWithSeparator()),
                unit: 'mm/s',
                maxValue: 8,
              ),
              SliderOrTextInput(
                value: ref.watch(_controllerProvider(machineUUID).selectRequireValue((data) => data.maxAccelToDecel)),
                prefixText: tr('pages.dashboard.control.limit_card.accel_to_decel'),
                onChange: canEdit ? controller.onEditedMaxAccelToDecel : null,
                numberFormat: NumberFormat('0 mm/s²', context.locale.toStringWithSeparator()),
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
class _Controller extends _$Controller {
  @override
  FutureOr<_Model> build(String machineUUID) {
    ref.keepAliveFor();

    final klippyAsync = ref.watch(klipperProvider(machineUUID).selectAs((value) => value.klippyCanReceiveCommands));
    final toolheadAsync = ref.watch(printerProvider(machineUUID).selectAs((value) => value.toolhead));

    final klippyCanReceiveCommands = klippyAsync.requireValue;
    final toolhead = toolheadAsync.requireValue;


    return _Model(
      klippyCanReceiveCommands: klippyCanReceiveCommands,
      maxVelocity: toolhead.maxVelocity,
      maxAccel: toolhead.maxAccel,
      squareCornerVelocity: toolhead.squareCornerVelocity,
      maxAccelToDecel: toolhead.maxAccelToDecel,
    );
  }

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

class _PreviewController extends _Controller {
  @override
  FutureOr<_Model> build(String machineUUID) {
    const model = _Model(
      klippyCanReceiveCommands: true,
      maxVelocity: 250,
      maxAccel: 4000,
      squareCornerVelocity: 5,
      maxAccelToDecel: 2000,
    );
    state = const AsyncValue.data(model);

    return model;
  }

  @override
  onEditedMaxVelocity(double value) {
    // do nothing in preview
  }

  @override
  onEditedMaxAccel(double value) {
    // do nothing in preview
  }

  @override
  onEditedMaxSquareCornerVelocity(double value) {
    // do nothing in preview
  }

  @override
  onEditedMaxAccelToDecel(double value) {
    // do nothing in preview
  }
}

@freezed
sealed class _Model with _$Model {
  const factory _Model({
    required bool klippyCanReceiveCommands,
    required double maxVelocity,
    required double maxAccel,
    required double squareCornerVelocity,
    required double maxAccelToDecel,
  }) = __Model;
}
