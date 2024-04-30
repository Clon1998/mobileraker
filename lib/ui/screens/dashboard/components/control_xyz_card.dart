/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:math';

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/printer_axis_enum.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/range_selector_skeleton.dart';
import 'package:common/ui/components/skeletons/square_elevated_icon_button_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/IconElevatedButton.dart';
import 'package:mobileraker/ui/components/homed_axis_chip.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/screens/dashboard/components/toolhead_info/toolhead_info_table.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

part 'control_xyz_card.freezed.dart';
part 'control_xyz_card.g.dart';

const _marginForBtns = EdgeInsets.all(10);

class ControlXYZCard extends HookConsumerWidget {
  const ControlXYZCard({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('Rebuilding ControlXYZCard.');

    return AsyncGuard(
      debugLabel: 'ControlXYZCard-$machineUUID',
      toGuard: _controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.showCard),
      childOnLoading: const _ControlXYZLoading(),
      childOnData: Card(
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
      ),
    );
  }
}

class _ControlXYZLoading extends StatelessWidget {
  const _ControlXYZLoading({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Card(
      child: Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: themeData.colorScheme.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CardTitleSkeleton(
              trailing: Chip(
                label: SizedBox(width: 45),
                backgroundColor: Colors.white,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // XYZMotion
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // XYMotion
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SquareElevatedIconButtonSkeleton(margin: _marginForBtns),
                          Row(
                            children: [
                              SquareElevatedIconButtonSkeleton(margin: _marginForBtns),
                              SquareElevatedIconButtonSkeleton(margin: _marginForBtns),
                              SquareElevatedIconButtonSkeleton(margin: _marginForBtns),
                            ],
                          ),
                          SquareElevatedIconButtonSkeleton(margin: _marginForBtns),
                        ],
                      ),
                      //ZMotion
                      Column(
                        children: [
                          SquareElevatedIconButtonSkeleton(margin: _marginForBtns),
                          SquareElevatedIconButtonSkeleton(margin: _marginForBtns),
                          SquareElevatedIconButtonSkeleton(margin: _marginForBtns),
                        ],
                      ),
                    ],
                  ),
                  // Placeholder for the ToolheadInfoTable
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: SizedBox(height: 54, width: double.infinity),
                  ),
                  // QuickActions
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Wrap(
                      runSpacing: 4,
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        SizedBox(
                          height: 40,
                          width: 80,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 40,
                          width: 80,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 40,
                          width: 80,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 40,
                          width: 80,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // StepSelector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 19, maxWidth: 100),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const RangeSelectorSkeleton(itemCount: 5),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(FlutterIcons.axis_arrow_mco),
      title: const Text('pages.dashboard.general.move_card.title').tr(),
      trailing: HomedAxisChip(machineUUID: machineUUID),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _XYMotionWidget(machineUUID: machineUUID),
            _ZMotionWidget(machineUUID: machineUUID),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ToolheadInfoTable(
            machineUUID: machineUUID,
            rowsToShow: const [ToolheadInfoTable.POS_ROW],
          ),
        ),
        _QuickActionsWidget(machineUUID: machineUUID),
        const Divider(),
        _StepSelectorWidget(machineUUID: machineUUID),
      ],
    );
  }
}

class _XYMotionWidget extends ConsumerWidget {
  const _XYMotionWidget({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyCanReceiveCommands = ref
        .watch(_controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands))
        .requireValue;
    var controller = ref.watch(_controlXYZCardControllerProvider(machineUUID).notifier);

    return Column(
      children: [
        SquareElevatedIconButton(
          margin: _marginForBtns,
          onPressed: klippyCanReceiveCommands ? () => controller.onMoveBtn(PrinterAxis.Y) : null,
          child: const Icon(FlutterIcons.upsquare_ant),
        ),
        Row(
          children: [
            SquareElevatedIconButton(
              margin: _marginForBtns,
              onPressed: klippyCanReceiveCommands ? () => controller.onMoveBtn(PrinterAxis.X, false) : null,
              child: const Icon(FlutterIcons.leftsquare_ant),
            ),
            Tooltip(
              message: 'pages.dashboard.general.move_card.home_xy_tooltip'.tr(),
              child: AsyncElevatedButton.squareIcon(
                margin: _marginForBtns,
                onPressed: klippyCanReceiveCommands
                    ? () => controller.onHomeAxisBtn(
                          {PrinterAxis.X, PrinterAxis.Y},
                        )
                    : null,
                icon: const Icon(Icons.home),
              ),
            ),
            SquareElevatedIconButton(
              margin: _marginForBtns,
              onPressed: klippyCanReceiveCommands ? () => controller.onMoveBtn(PrinterAxis.X) : null,
              child: const Icon(FlutterIcons.rightsquare_ant),
            ),
          ],
        ),
        SquareElevatedIconButton(
          margin: _marginForBtns,
          onPressed: klippyCanReceiveCommands ? () => controller.onMoveBtn(PrinterAxis.Y, false) : null,
          child: const Icon(FlutterIcons.downsquare_ant),
        ),
      ],
    );
  }
}

class _ZMotionWidget extends ConsumerWidget {
  const _ZMotionWidget({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyCanReceiveCommands = ref
        .watch(_controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands))
        .requireValue;
    var controller = ref.watch(_controlXYZCardControllerProvider(machineUUID).notifier);

    return Column(
      children: [
        SquareElevatedIconButton(
          margin: _marginForBtns,
          onPressed: klippyCanReceiveCommands ? () => controller.onMoveBtn(PrinterAxis.Z) : null,
          child: const Icon(FlutterIcons.upsquare_ant),
        ),
        Tooltip(
          message: 'pages.dashboard.general.move_card.home_z_tooltip'.tr(),
          child: AsyncElevatedButton.squareIcon(
            margin: _marginForBtns,
            onPressed: klippyCanReceiveCommands ? () => controller.onHomeAxisBtn({PrinterAxis.Z}) : null,
            icon: const Icon(Icons.home),
          ),
        ),
        SquareElevatedIconButton(
          margin: _marginForBtns,
          onPressed: klippyCanReceiveCommands ? () => controller.onMoveBtn(PrinterAxis.Z, false) : null,
          child: const Icon(FlutterIcons.downsquare_ant),
        ),
      ],
    );
  }
}

class _QuickActionsWidget extends ConsumerWidget {
  const _QuickActionsWidget({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyCanReceiveCommands = ref
        .watch(_controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands))
        .requireValue;
    var directActions =
        ref.watch(_controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.directActions)).requireValue;

    return Wrap(
      runSpacing: 4,
      spacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ...[
          for (var action in directActions)
            Tooltip(
              message: action.description,
              child: AsyncElevatedButton.icon(
                onPressed: klippyCanReceiveCommands ? action.callback : null,
                icon: Icon(action.icon),
                label: Text(action.title.toUpperCase()),
              ),
            ),
        ],
        _MoreActionsPopup(machineUUID: machineUUID),
      ],
    );
  }
}

class _MoreActionsPopup extends ConsumerWidget {
  const _MoreActionsPopup({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var klippyCanReceiveCommands = ref
        .watch(_controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands))
        .requireValue;
    var moreActions =
        ref.watch(_controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.moreActions)).requireValue;

    bool enabled = klippyCanReceiveCommands && moreActions.any((e) => e.callback != null);

    return PopupMenuButton(
      enabled: enabled,
      position: PopupMenuPosition.over,
      itemBuilder: (_) => [
        for (var action in moreActions)
          PopupMenuItem(
            enabled: klippyCanReceiveCommands,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onTap: action.callback,
            child: ListTile(
              enabled: action.callback != null,
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(action.icon),
              title: Text(action.title),
              subtitle: Text(action.description),
            ),
          ),
      ],
      child: ElevatedButton.icon(
        style: enabled
            ? ElevatedButton.styleFrom(
                disabledBackgroundColor: themeData.colorScheme.primary,
                disabledForegroundColor: themeData.colorScheme.onPrimary,
              )
            : null,
        onPressed: null,
        icon: const Icon(Icons.more_vert),
        label: const Text('@.upper:pages.dashboard.general.move_card.more_btn').tr(),
      ),
    );
  }
}

class _StepSelectorWidget extends ConsumerWidget {
  const _StepSelectorWidget({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var numberFormat = NumberFormat.decimalPattern(context.locale.toStringWithSeparator());

    var controller = ref.watch(_controlXYZCardControllerProvider(machineUUID).notifier);
    var klippyCanReceiveCommands = ref
        .watch(_controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands))
        .requireValue;
    var selected =
        ref.watch(_controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.selected)).requireValue;
    var steps = ref.watch(_controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.steps)).requireValue;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          child: Text(
            '${'pages.dashboard.general.move_card.step_size'.tr()} [mm]',
          ),
        ),
        RangeSelector(
          selectedIndex: selected,
          onSelected: klippyCanReceiveCommands ? controller.onSelectedChanged : null,
          values: [for (var step in steps) numberFormat.format(step)],
        ),
      ],
    );
  }
}

@riverpod
class _ControlXYZCardController extends _$ControlXYZCardController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.moveStepIndex, machineUUID);

  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.keepAliveFor();

    // await Future.delayed(Duration(seconds: 5));

    var klippyCanReceiveCommands = ref.watchAsSubject(
      klipperProvider(machineUUID).selectAs((value) => value.klippyCanReceiveCommands),
    );

    var showCard =
        ref.watchAsSubject(printerProvider(machineUUID).selectAs((data) => data.print.state != PrintState.printing));

    var steps = ref.watchAsSubject(machineSettingsProvider(machineUUID).selectAs((data) => data.moveSteps));

    // Using a combination of select and map here to avoid excessive calls to _quickActions when the printer changes
    var actions = ref
        .watchAsSubject(printerProvider(machineUUID).selectAs((data) => data.configFile))
        .map((data) => _quickActions(data));

    var initialIndex = _settingService.readInt(_settingsKey, 0);

    yield* Rx.combineLatest4(
      showCard,
      klippyCanReceiveCommands,
      actions,
      steps,
      (a, b, c, d) {
        var idx = state.whenData((value) => value.selected).valueOrNull ?? initialIndex.clamp(0, d.length - 1);

        return _Model(
          showCard: a,
          klippyCanReceiveCommands: b,
          directActions: c.$1,
          moreActions: c.$2,
          steps: d,
          selected: min(max(0, idx), d.length - 1),
        );
      },
    );
  }

  void onSelectedChanged(int? index) {
    if (index == null) return;
    state = state.whenData((value) => value.copyWith(selected: index));
    _settingService.writeInt(_settingsKey, index);
  }

  Future<void> onMoveBtn(PrinterAxis axis, [bool positive = true]) async {
    var machineSettings = ref.read(machineSettingsProvider(machineUUID)).valueOrNull;
    if (machineSettings == null) return;

    var step = state.value?.let((it) => it.steps.elementAtOrNull(it.selected));
    if (step == null) return;
    bool invert = switch (axis) {
          PrinterAxis.X => machineSettings.inverts.elementAtOrNull(0),
          PrinterAxis.Y => machineSettings.inverts.elementAtOrNull(1),
          PrinterAxis.Z => machineSettings.inverts.elementAtOrNull(2),
          _ => throw ArgumentError('Can not determine inverts, invalid axis: $axis'),
        } ==
        true;
    double dirStep = (positive ^ invert) ? step : -1 * step;

    await switch (axis) {
      PrinterAxis.X => _printerService.movePrintHead(
          x: dirStep,
          feedRate: machineSettings.speedXY.toDouble(),
        ),
      PrinterAxis.Y => _printerService.movePrintHead(
          y: dirStep,
          feedRate: machineSettings.speedXY.toDouble(),
        ),
      PrinterAxis.Z => _printerService.movePrintHead(
          z: dirStep,
          feedRate: machineSettings.speedZ.toDouble(),
        ),
      _ => throw ArgumentError('Invalid axis: $axis'),
    };
  }

  Future<void> onHomeAxisBtn(Set<PrinterAxis> axis) => _printerService.homePrintHead(axis);

  Future<void> onQuadGantry() => _printerService.quadGantryLevel();

  Future<void> onBedMesh() => _printerService.bedMeshLevel();

  Future<void> onMotorOff() => _printerService.m84();

  Future<void> onZTiltAdjust() => _printerService.zTiltAdjust();

  Future<void> onScrewTiltCalc() => _printerService.screwsTiltCalculate();

  Future<void> onSaveConfig() => _printerService.saveConfig();

  Future<void> onProbeCalibration() => _printerService.probeCalibrate();

  Future<void> onZEndstopCalibration() => _printerService.zEndstopCalibrate();

  Future<void> onBedScrewAdjust() => _printerService.bedScrewsAdjust();

  (List<_QuickAction>, List<_QuickAction>) _quickActions(ConfigFile configFile) {
    List<_QuickAction> directActions = [
      _QuickAction(
        title: tr('pages.dashboard.general.move_card.home_all_btn'),
        description: tr('pages.dashboard.general.move_card.home_all_tooltip'),
        icon: Icons.home,
        callback: () => onHomeAxisBtn(
          {PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z},
        ),
      ),
      if (configFile.hasQuadGantry == true)
        _QuickAction(
          title: tr('pages.dashboard.general.move_card.qgl_btn'),
          description: tr('pages.dashboard.general.move_card.qgl_tooltip'),
          icon: FlutterIcons.quadcopter_mco,
          callback: onQuadGantry,
        ),
      if (configFile.hasBedMesh == true)
        _QuickAction(
          title: tr('pages.dashboard.general.move_card.mesh_btn'),
          description: tr('pages.dashboard.general.move_card.mesh_tooltip'),
          icon: FlutterIcons.map_marker_path_mco,
          callback: onBedMesh,
        ),
      if (configFile.hasScrewTiltAdjust == true)
        _QuickAction(
          title: tr('pages.dashboard.general.move_card.stc_btn'),
          description: tr('pages.dashboard.general.move_card.stc_tooltip'),
          icon: FlutterIcons.screw_machine_flat_top_mco,
          callback: onScrewTiltCalc,
        ),
      if (configFile.hasZTilt == true)
        _QuickAction(
          title: tr('pages.dashboard.general.move_card.ztilt_btn'),
          description: tr('pages.dashboard.general.move_card.ztilt_tooltip'),
          icon: Icons.architecture,
          callback: onZTiltAdjust,
        ),
    ];

    List<_QuickAction> calibrationActions = [
      if (configFile.hasProbe == true)
        _QuickAction(
          title: 'pages.dashboard.general.move_card.poff_btn'.tr(),
          description: 'pages.dashboard.general.move_card.poff_tooltip'.tr(),
          icon: FlutterIcons.grease_pencil_mco,
          callback: onProbeCalibration,
        ),
      if (configFile.hasBedScrews == true)
        _QuickAction(
          title: tr('pages.dashboard.general.move_card.bsa_btn'),
          description: tr('pages.dashboard.general.move_card.bsa_tooltip'),
          icon: FlutterIcons.axis_z_rotate_clockwise_mco,
          callback: onBedScrewAdjust,
        ),
      if (configFile.hasVirtualZEndstop == false)
        _QuickAction(
          title: 'pages.dashboard.general.move_card.zoff_btn'.tr(),
          description: 'pages.dashboard.general.move_card.zoff_tooltip'.tr(),
          icon: Icons.vertical_align_bottom,
          callback: onZEndstopCalibration,
        ),
      _QuickAction(
        title: 'pages.dashboard.general.move_card.save_btn'.tr(),
        description: 'pages.dashboard.general.move_card.save_tooltip'.tr(),
        icon: Icons.save_alt,
        callback: onSaveConfig,
      ),
    ];

    var m84 = _QuickAction(
      title: tr('pages.dashboard.general.move_card.m84_btn'),
      description: tr('pages.dashboard.general.move_card.m84_tooltip'),
      icon: Icons.near_me_disabled,
      callback: onMotorOff,
    );

    if (directActions.length < 3) {
      directActions.add(m84);
    } else {
      calibrationActions.insert(0, m84);
      calibrationActions.addAll(directActions.sublist(3));
      directActions = directActions.sublist(0, min(directActions.length, 3));
    }

    return (directActions, calibrationActions);
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required bool showCard,
    required bool klippyCanReceiveCommands,
    required int selected,
    required List<double> steps,
    @Default([]) List<_QuickAction> directActions,
    @Default([]) List<_QuickAction> moreActions,
  }) = __Model;
}

@freezed
class _QuickAction with _$QuickAction {
  const factory _QuickAction({
    required String title,
    required String description,
    required IconData icon,
    required FutureOr<void>? Function()? callback,
  }) = __QuickAction;
}
