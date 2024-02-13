/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:math';

import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/range_selector_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../service/ui/dialog_service_impl.dart';
import '../../../components/dialog/edit_form/num_edit_form_controller.dart';

part 'control_extruder_card.freezed.dart';
part 'control_extruder_card.g.dart';

class ControlExtruderCard extends ConsumerWidget {
  const ControlExtruderCard({Key? key, required this.machineUUID}) : super(key: key);

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var showLoading = ref.watch(
        _controlExtruderCardControllerProvider(machineUUID).select((value) => value.isLoading && !value.isReloading));

    if (showLoading) return const _ControlExtruderLoading();

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CardTitle(machineUUID: machineUUID),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: _CardBody(machineUUID: machineUUID),
          ),
        ],
      ),
    );
  }
}

class _ControlExtruderLoading extends StatelessWidget {
  const _ControlExtruderLoading({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Card(
      child: Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: themeData.colorScheme.background,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CardTitleSkeleton(),
            Padding(
              padding: EdgeInsets.only(left: 8, right: 8, bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Extruder buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: SizedBox(
                          height: 40,
                          width: 104,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: SizedBox(
                          height: 40,
                          width: 104,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Step selecotr with title
                  Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: SizedBox(
                          height: 19,
                          width: 142,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white),
                          ),
                        ),
                      ),
                      RangeSelectorSkeleton(itemCount: 5),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends ConsumerWidget {
  const _CardTitle({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(_controlExtruderCardControllerProvider(machineUUID).select((value) => value.requireValue));
    var controller = ref.watch(_controlExtruderCardControllerProvider(machineUUID).notifier);

    return ListTile(
      leading: const Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
      title: Row(
        children: [
          const Text('pages.dashboard.control.extrude_card.title').tr(),
          AnimatedOpacity(
            opacity: model.minExtrudeTempReached ? 0 : 1,
            duration: kThemeAnimationDuration,
            child: Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Tooltip(
                margin: const EdgeInsets.symmetric(horizontal: 64.0),
                // textAlign: TextAlign.justify,
                message: tr(
                  'pages.dashboard.control.extrude_card.cold_extrude_error',
                  args: [model.minExtrudeTemp.toStringAsFixed(0)],
                ),
                child: Icon(
                  Icons.severe_cold,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
      trailing: model.extruderCount <= 1
          ? null
          : DropdownButton(
              value: model.extruderIndex,
              onChanged: model.klippyCanReceiveCommands ? controller.onExtruderSelected : null,
              items: List.generate(model.extruderCount, (index) {
                String name = tr('pages.dashboard.control.extrude_card.title');
                if (index > 0) name += ' $index';
                return DropdownMenuItem(value: index, child: Text(name));
              }),
            ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(_controlExtruderCardControllerProvider(machineUUID).select((value) => value.requireValue));
    var controller = ref.watch(_controlExtruderCardControllerProvider(machineUUID).notifier);

    var canExtrude = model.minExtrudeTempReached && model.klippyCanReceiveCommands;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(FlutterIcons.minus_ant),
              label: const Text(
                'pages.dashboard.control.extrude_card.retract',
              ).tr(),
              onPressed: canExtrude ? () => controller.onMoveE(true) : null,
            ),
            IconButton(onPressed: controller.onFeedrateButtonPressed, icon: const Icon(Icons.speed)),
            ElevatedButton.icon(
              icon: const Icon(FlutterIcons.plus_ant),
              label: const Text(
                'pages.dashboard.control.extrude_card.extrude',
              ).tr(),
              onPressed: canExtrude ? () => controller.onMoveE() : null,
            ),
          ],
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${tr('pages.dashboard.control.extrude_card.extrude_len')} [mm]',
              ),
            ),
            RangeSelector(
              selectedIndex: model.stepIndex,
              onSelected: canExtrude ? controller.onSelectedStepChanged : null,
              values: [for (var step in model.steps) step.toString()],
            ),
          ],
        ),
      ],
    );
  }
}

@riverpod
class _ControlExtruderCardController extends _$ControlExtruderCardController {
  DialogService get _dialogService => ref.read(dialogServiceProvider);

  SettingService get _settingService => ref.read(settingServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.extruderStepIndex, machineUUID);

  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.keepAliveFor();
    // await Future.delayed(Duration(seconds: 5));

    // The active extruder (Set via klipper/moonraker) is watched and based on it, the streams are constructed
    var activeExtruder =
        await ref.watch(printerProvider(machineUUID).selectAsync((data) => data.toolhead.activeExtruderIndex));

    // Below is stream code to prevent to many controller rebuilds
    var klippyCanReceiveCommands = ref.watchAsSubject(
      klipperProvider(machineUUID).selectAs((value) => value.klippyCanReceiveCommands),
    );
    var steps = ref.watchAsSubject(machineSettingsProvider(machineUUID).selectAs((data) => data.extrudeSteps));
    var printer = ref.watchAsSubject(printerProvider(machineUUID));

    var initialIndex = _settingService.readInt(_settingsKey, 0);
    var initialVelocity =
        await ref.watch(machineSettingsProvider(machineUUID).selectAsync((data) => data.extrudeFeedrate.toDouble()));

    yield* Rx.combineLatest3(
      klippyCanReceiveCommands,
      printer,
      steps,
      (a, b, c) {
        var idx = state.whenData((value) => value.stepIndex).valueOrNull ?? initialIndex;
        var velocity = state.whenData((value) => value.extruderVelocity).valueOrNull ?? initialVelocity;

        var minExtrudeTemp = b.configFile.extruderForIndex(activeExtruder)?.minExtrudeTemp ?? 170;
        return _Model(
          klippyCanReceiveCommands: a,
          extruderCount: b.extruderCount,
          extruderIndex: activeExtruder,
          stepIndex: min(max(0, idx), c.length - 1),
          steps: c,
          minExtrudeTemp: minExtrudeTemp,
          minExtrudeTempReached: (b.extruders.elementAtOrNull(activeExtruder)?.temperature ?? 0) >= minExtrudeTemp,
          extruderVelocity: velocity,
        );
      },
    );
  }

  void onExtruderSelected(int? idx) {
    state = state.toLoading();
    if (idx != null) _printerService.activateExtruder(idx);
  }

  Future<void> onMoveE([bool isRetract = false]) async {
    var machineSettings = ref.read(machineSettingsProvider(machineUUID)).valueOrNull;
    if (machineSettings == null) return;

    var step = state.value?.let((it) => it.steps.elementAtOrNull(it.stepIndex));
    if (step == null) return;

    var velocity = state.value?.let((it) => it.extruderVelocity);
    if (velocity == null) return;

    HapticFeedback.selectionClick();
    await _printerService.moveExtruder(
      (isRetract ? step * -1 : step).toDouble(),
      velocity,
    );
  }

  void onSelectedStepChanged(int? index) {
    if (index == null) return;
    state = state.whenData((value) => value.copyWith(stepIndex: index));
    _settingService.writeInt(_settingsKey, index);
  }

  void onFeedrateButtonPressed() {
    var maxVelocity = ref
        .read(printerProvider(machineUUID).selectAs((data) => data.configFile.primaryExtruder?.maxExtrudeOnlyVelocity))
        .valueOrNull
        ?.floorToDouble();

    _dialogService
        .show(DialogRequest(
      type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
          ? DialogType.numEdit
          : DialogType.rangeEdit,
      title: tr('dialogs.extruder_feedrate.title'),
      cancelBtn: tr('general.cancel'),
      confirmBtn: tr('general.confirm'),
      data: NumberEditDialogArguments(
        current: state.requireValue.extruderVelocity,
        min: 0.1,
        max: maxVelocity ?? 20,
        fraction: 1,
      ),
    ))
        .then((value) {
      if (value != null && value.confirmed && value.data != null) {
        num v = value.data;
        state = state.whenData((s) => s.copyWith(extruderVelocity: v.toDouble().toPrecision(1)));
      }
    });
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required bool klippyCanReceiveCommands,
    @Default(1) int extruderCount,
    required int extruderIndex,
    required int stepIndex,
    required List<int> steps,
    @Default(170) double minExtrudeTemp,
    @Default(false) bool minExtrudeTempReached,
    required double extruderVelocity,
  }) = __Model;
}
