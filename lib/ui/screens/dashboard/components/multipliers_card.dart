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
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import '../dashboard_controller.dart';
import 'SliderOrTextInput.dart';

part 'multipliers_card.freezed.dart';

part 'multipliers_card.g.dart';

class MultipliersCard extends StatelessWidget {
  const MultipliersCard({
    super.key,
    required this.machineUUID,
  });

  final String machineUUID;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: MultipliersSlidersOrTexts(
          machineUUID: machineUUID,
        ),
      ),
    );
  }
}

class MultipliersSlidersOrTextsLoading extends StatelessWidget {
  const MultipliersSlidersOrTextsLoading({super.key});

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
                SliderOrTextInputSkeleton(
                  value: 0.9,
                ),
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
  const MultipliersSlidersOrTexts({
    Key? key,
    required this.machineUUID,
  }) : super(key: key);

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var showLoading =
        ref.watch(_controllerProvider(machineUUID).select((value) => value.isLoading && !value.isReloading));

    if (showLoading) {
      return const MultipliersSlidersOrTextsLoading();
    }

    var inputLocked = useState(true);

    var controller = ref.watch(_controllerProvider(machineUUID).notifier);
    var klippyCanReceiveCommands =
        ref.watch(_controllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands)).value!;

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
                onChange: canEdit ? controller.onEditedSpeedMultiplier : null,
                addToMax: true,
              ),
              SliderOrTextInput(
                  provider: machinePrinterKlippySettingsProvider
                      .select((data) => data.value!.printerData.gCodeMove.extrudeFactor),
                  prefixText: 'pages.dashboard.control.multipl_card.flow'.tr(),
                  onChange: canEdit ? controller.onEditedFlowMultiplier : null),
              SliderOrTextInput(
                provider: machinePrinterKlippySettingsProvider
                    .select((data) => data.value!.printerData.extruder.pressureAdvance),
                prefixText: 'pages.dashboard.control.multipl_card.press_adv'.tr(),
                onChange: canEdit ? controller.onEditedPressureAdvanced : null,
                numberFormat: NumberFormat('0.##### mm/s', context.locale.languageCode),
                unit: 'mm/s',
              ),
              SliderOrTextInput(
                provider:
                    machinePrinterKlippySettingsProvider.select((data) => data.value!.printerData.extruder.smoothTime),
                prefixText: 'pages.dashboard.control.multipl_card.smooth_time'.tr(),
                onChange: canEdit ? controller.onEditedSmoothTime : null,
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
class _Controller extends _$Controller {
  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.timeoutKeepAlive();

    var klippyCanReceiveCommands =
        ref.watchAsSubject(klipperProvider(machineUUID).selectAs((value) => value.klippyCanReceiveCommands));
    var extruder = ref.watchAsSubject(printerProvider(machineUUID).selectAs((value) => value.extruder));
    var gCodeMove = ref.watchAsSubject(printerProvider(machineUUID).selectAs((value) => value.gCodeMove));

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
            ));
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
