/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: prefer-single-widget-per-file

import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/slider_or_text_input_skeleton.dart';
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
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import 'slider_or_text_input.dart';

part 'multipliers_card.freezed.dart';
part 'multipliers_card.g.dart';

class MultipliersCard extends HookWidget {
  const MultipliersCard({super.key, required this.machineUUID});

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
        child: MultipliersSlidersOrTexts(machineUUID: machineUUID),
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
        _controllerProvider(_machineUUID).overrideWith(_PreviewController.new),
      ],
      child: isCard
          ? const MultipliersCard(machineUUID: _machineUUID)
          : const MultipliersSlidersOrTexts(machineUUID: _machineUUID),
    );
  }
}

class _MultipliersSlidersOrTextsLoading extends StatelessWidget {
  const _MultipliersSlidersOrTextsLoading({super.key});

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
                SliderOrTextInputSkeleton(value: 0.9),
                SliderOrTextInputSkeleton(value: 0.3),
                SliderOrTextInputSkeleton(value: 0.65),
                SliderOrTextInputSkeleton(value: 0.8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MultipliersSlidersOrTexts extends HookConsumerWidget {
  const MultipliersSlidersOrTexts({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview(isCard: false);
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncGuard(
      debugLabel: 'MultipliersSlidersOrTexts-$machineUUID',
      toGuard: _controllerProvider(machineUUID).selectAs((data) => true),
      childOnLoading: const _MultipliersSlidersOrTextsLoading(),
      childOnData: _Body(
        machineUUID: machineUUID,
      ),
    );
  }
}

class _Body extends HookConsumerWidget {
  const _Body({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('Building MultipliersBody for $machineUUID');

    var inputLocked = useState(true);
    var controller = ref.watch(_controllerProvider(machineUUID).notifier);

    var klippyCanReceiveCommands =
        ref.watch(_controllerProvider(machineUUID).selectRequireValue((data) => data.klippyCanReceiveCommands));

    var canEdit = klippyCanReceiveCommands && !inputLocked.value;

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
                provider: _controllerProvider(machineUUID).selectRequireValue(
                  (data) => data.speedFactor,
                ),
                prefixText: 'pages.dashboard.general.print_card.speed'.tr(),
                onChange: canEdit ? controller.onEditedSpeedMultiplier : null,
                addToMax: true,
              ),
              SliderOrTextInput(
                provider: _controllerProvider(machineUUID).selectRequireValue(
                  (data) => data.extrudeFactor,
                ),
                prefixText: 'pages.dashboard.control.multipl_card.flow'.tr(),
                onChange: canEdit ? controller.onEditedFlowMultiplier : null,
              ),
              SliderOrTextInput(
                provider: _controllerProvider(machineUUID).selectRequireValue(
                  (data) => data.pressureAdvance,
                ),
                prefixText: 'pages.dashboard.control.multipl_card.press_adv'.tr(),
                onChange: canEdit ? controller.onEditedPressureAdvanced : null,
                numberFormat: NumberFormat('0.##### mm/s', context.locale.toStringWithSeparator()),
                unit: 'mm/s',
              ),
              SliderOrTextInput(
                provider: _controllerProvider(machineUUID).selectRequireValue(
                  (data) => data.smoothTime,
                ),
                prefixText: 'pages.dashboard.control.multipl_card.smooth_time'.tr(),
                onChange: canEdit ? controller.onEditedSmoothTime : null,
                numberFormat: NumberFormat('0.### s', context.locale.toStringWithSeparator()),
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
class _Controller extends _$Controller {
  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.keepAliveFor();

    var klippyCanReceiveCommands = ref.watchAsSubject(
      klipperProvider(machineUUID).selectAs((value) => value.klippyCanReceiveCommands),
    );
    var extruder = ref.watchAsSubject(
      printerProvider(machineUUID).selectAs((value) => value.extruder),
    );
    var gCodeMove = ref.watchAsSubject(
      printerProvider(machineUUID).selectAs((value) => value.gCodeMove),
    );

    yield* Rx.combineLatest3(
      klippyCanReceiveCommands,
      extruder,
      gCodeMove,
      (a, b, c) => _Model(
        klippyCanReceiveCommands: a,
        speedFactor: c.speedFactor,
        extrudeFactor: c.extrudeFactor,
        pressureAdvance: b.pressureAdvance,
        smoothTime: b.smoothTime,
      ),
    );
  }

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

@riverpod
class _PreviewController extends _Controller {
  @override
  Stream<_Model> build(String machineUUID) {
    state = const AsyncValue.data(_Model(
      klippyCanReceiveCommands: true,
      speedFactor: 1.25,
      extrudeFactor: 0.98,
      pressureAdvance: 0.65,
      smoothTime: 0.069,
    ));

    return const Stream.empty();
  }

  @override
  onEditedSpeedMultiplier(double value) {
    // do nothing preview
  }

  @override
  onEditedFlowMultiplier(double value) {
    // do nothing preview
  }

  @override
  onEditedPressureAdvanced(double value) {
    // do nothing preview
  }

  @override
  onEditedSmoothTime(double value) {
    // do nothing preview
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required bool klippyCanReceiveCommands,
    required double speedFactor,
    required double extrudeFactor,
    required double pressureAdvance,
    required double smoothTime,
  }) = __Model;
}
