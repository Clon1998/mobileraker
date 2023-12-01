/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/machine/printer_axis_enum.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/range_selector_skeleton.dart';
import 'package:common/ui/components/skeletons/square_elevated_icon_button_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import '../../../components/IconElevatedButton.dart';
import '../../../components/range_selector.dart';

part 'z_offset_card.freezed.dart';
part 'z_offset_card.g.dart';

class ZOffsetCard extends ConsumerWidget {
  const ZOffsetCard({Key? key, required this.machineUUID}) : super(key: key);

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var showLoading =
        ref.watch(_zOffsetCardControllerProvider(machineUUID).select((value) => value.isLoading && !value.isReloading));

    if (showLoading) return const _ZOffsetLoading();

    return Card(
      child: Column(
        children: <Widget>[
          _CardTitle(machineUUID: machineUUID),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: _CardBody(machineUUID: machineUUID),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }
}

class _ZOffsetLoading extends StatelessWidget {
  const _ZOffsetLoading({super.key});

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
            CardTitleSkeleton(
              trailing: Chip(
                label: SizedBox(width: 90),
                backgroundColor: Colors.white,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      SquareElevatedIconButtonSkeleton(margin: EdgeInsets.all(10)),
                      SquareElevatedIconButtonSkeleton(margin: EdgeInsets.all(10)),
                    ],
                  ),
                  Column(children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: 100,
                        height: 19,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                    ),
                    RangeSelectorSkeleton(itemCount: 4),
                  ]),
                ],
              ),
            ),
            SizedBox(height: 15),
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
    var zOffset = ref.watch(_ZOffsetCardControllerProvider(machineUUID).selectAs((data) => data.zOffset)).value!;

    return ListTile(
      leading: const Icon(FlutterIcons.align_vertical_middle_ent),
      title: const Text('pages.dashboard.general.baby_step_card.title').tr(),
      trailing: Chip(
        avatar: Icon(
          FlutterIcons.progress_wrench_mco,
          color: Theme.of(context).iconTheme.color,
          size: 20,
        ),
        label: Text('${zOffset.toPrecision(3).toStringAsFixed(3)}mm'),
      ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_zOffsetCardControllerProvider(machineUUID).notifier);
    var klippyCanReceiveCommands =
        ref.watch(_zOffsetCardControllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands)).value!;
    var selected = ref.watch(_zOffsetCardControllerProvider(machineUUID).selectAs((data) => data.selected)).value!;
    var steps = ref.watch(_zOffsetCardControllerProvider(machineUUID).selectAs((data) => data.steps)).value!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Column(
          children: [
            SquareElevatedIconButton(
              margin: const EdgeInsets.all(10),
              onPressed: klippyCanReceiveCommands ? () => controller.onBabyStepping(true) : null,
              child: const Icon(FlutterIcons.upsquare_ant),
            ),
            SquareElevatedIconButton(
              margin: const EdgeInsets.all(10),
              onPressed: klippyCanReceiveCommands ? () => controller.onBabyStepping(false) : null,
              child: const Icon(FlutterIcons.downsquare_ant),
            ),
          ],
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${'pages.dashboard.general.move_card.step_size'.tr()} [mm]',
              ),
            ),
            RangeSelector(
              selectedIndex: selected,
              onSelected: klippyCanReceiveCommands ? controller.onSelectedChanged : null,
              values: [for (var step in steps) step.toStringAsFixed(3)],
            ),
          ],
        ),
      ],
    );
  }
}

@riverpod
class _ZOffsetCardController extends _$ZOffsetCardController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.zOffsetStepIndex, machineUUID);

  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.keepAliveFor();

    var klippyCanReceiveCommands = ref.watchAsSubject(
      klipperProvider(machineUUID).selectAs((value) => value.klippyCanReceiveCommands),
    );

    var zOffset = ref.watchAsSubject(printerProvider(machineUUID).selectAs((data) => data.zOffset));

    var steps = ref.watchAsSubject(machineSettingsProvider(machineUUID).selectAs((data) => data.babySteps));

    var initialIndex = _settingService.readInt(_settingsKey, 0);

    yield* Rx.combineLatest3(
      klippyCanReceiveCommands,
      zOffset,
      steps,
      (a, b, c) {
        var idx = state.whenData((value) => value.selected).valueOrNull ?? initialIndex;

        return _Model(
          klippyCanReceiveCommands: a,
          zOffset: b,
          steps: c,
          selected: min(max(0, idx), c.length - 1),
        );
      },
    );
  }

  void onSelectedChanged(int? index) {
    if (index == null) return;
    state = state.whenData((value) => value.copyWith(selected: index));
    _settingService.writeInt(_settingsKey, index);
  }

  void onBabyStepping(bool positive) {
    var step = state.value?.let((it) => it.steps.elementAtOrNull(it.selected));
    if (step == null) return;

    double dirStep = (positive) ? step : -1 * step;
    var zHomed = ref.read(printerProvider(machineUUID)).value?.toolhead.homedAxes.contains(PrinterAxis.Z) ?? false;
    _printerService.setGcodeOffset(z: dirStep, move: zHomed ? 1 : 0);
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required bool klippyCanReceiveCommands,
    required double zOffset,
    required List<double> steps,
    required int selected,
  }) = __Model;
}
