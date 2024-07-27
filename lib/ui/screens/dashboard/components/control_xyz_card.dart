/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:math';

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/printer_axis_enum.dart';
import 'package:common/data/dto/machine/printer_builder.dart';
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
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/IconElevatedButton.dart';
import 'package:mobileraker/ui/components/homed_axis_chip.dart';
import 'package:mobileraker/ui/components/single_value_selector.dart';
import 'package:mobileraker/ui/screens/dashboard/components/toolhead_info/toolhead_info_table.dart';
import 'package:overflow_view/overflow_view.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import 'toolhead_info/toolhead_info_table_controller.dart';

part 'control_xyz_card.freezed.dart';
part 'control_xyz_card.g.dart';

const _marginForBtns = EdgeInsets.all(10);

class ControlXYZCard extends HookConsumerWidget {
  const ControlXYZCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview();
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    logger.i('Rebuilding ControlXYZCard.');

    return AsyncGuard(
      animate: true,
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

class _Preview extends HookWidget {
  static const String _machineUUID = 'preview';

  const _Preview({super.key});

  @override
  Widget build(BuildContext context) {
    useAutomaticKeepAlive();
    return ProviderScope(
      overrides: [
        _controlXYZCardControllerProvider(_machineUUID).overrideWith(_ControlXYZCardPreviewController.new),
        printerProvider(_machineUUID).overrideWith((provider) => Stream.value(PrinterBuilder.preview().build())),
        toolheadInfoProvider(_machineUUID).overrideWith(
          (provider) => Stream.value(
            const ToolheadInfo(
              postion: [5, 5, 10],
              printingOrPaused: false,
              mmSpeed: 200,
              currentLayer: 1,
              maxLayers: 10,
              usedFilamentPerc: 0,
              totalDuration: 0,
            ),
          ),
        ),
      ],
      child: const ControlXYZCard(machineUUID: _machineUUID),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate the number of buttons that can fit in one row
                        double buttonWidth = 80;
                        double availableWidth = constraints.maxWidth;
                        int buttons = (availableWidth / (buttonWidth + 8)).floor(); // Including spacing

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (buttons < 0)
                              SizedBox(
                                height: 40,
                                width: availableWidth,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(color: Colors.white),
                                ),
                              ),
                            for (int i = 0; i < buttons; i++)
                              Padding(
                                padding: i == 0 ? EdgeInsets.zero : const EdgeInsets.only(left: 8.0),
                                child: SizedBox(
                                  height: 40,
                                  width: buttonWidth,
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
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
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 19, maxWidth: 100),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(color: Colors.white),
                            ),
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

    return OverflowView.flexible(
      // Either layout the children horizontally (the default)
      // or vertically.
      direction: Axis.horizontal,
      // The amount of space between children.
      spacing: 8,
      // The widgets to display until there is not enough space.
      children: <Widget>[
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
      // The overview indicator showed if there is not enough space for
      // all chidren.
      builder: (context, remaining) {
        final moreActions = directActions.sublist(directActions.length - remaining);

        return _MoreActionsPopup(machineUUID: machineUUID, moreActions: moreActions);
      },
    );
  }
}

class _MoreActionsPopup extends ConsumerWidget {
  const _MoreActionsPopup({super.key, required this.machineUUID, required this.moreActions});

  final String machineUUID;

  final List<_QuickAction> moreActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var klippyCanReceiveCommands = ref
        .watch(_controlXYZCardControllerProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands))
        .requireValue;

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
        label: const Text(
          '@.upper:pages.dashboard.general.move_card.more_btn',
          maxLines: 1,
        ).tr(),
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

    return OverflowBar(
      alignment: MainAxisAlignment.spaceEvenly,
      spacing: 4,
      overflowAlignment: OverflowBarAlignment.center,
      children: [
        Text(
          '${'pages.dashboard.general.move_card.step_size'.tr()} [mm]',
          textAlign: TextAlign.center,
        ),
        SingleValueSelector(
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
          directActions: c,
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

  List<_QuickAction> _quickActions(ConfigFile configFile) {
    return [
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
      _QuickAction(
        title: tr('pages.dashboard.general.move_card.m84_btn'),
        description: tr('pages.dashboard.general.move_card.m84_tooltip'),
        icon: Icons.near_me_disabled,
        callback: onMotorOff,
      ),
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
  }
}

class _ControlXYZCardPreviewController extends _ControlXYZCardController {
  @override
  Stream<_Model> build(String machineUUID) {
    logger.i('Building ControlXYZCardPreviewController for $machineUUID.');

    state = AsyncValue.data(_Model(
      showCard: true,
      klippyCanReceiveCommands: true,
      selected: 2,
      steps: [1, 5, 25, 50, 100],
      directActions: [
        _QuickAction(
          title: tr('pages.dashboard.general.move_card.home_all_btn'),
          description: tr('pages.dashboard.general.move_card.home_all_tooltip'),
          icon: Icons.home,
          callback: () => null,
        ),
        _QuickAction(
          title: tr('pages.dashboard.general.move_card.m84_btn'),
          description: tr('pages.dashboard.general.move_card.m84_tooltip'),
          icon: Icons.near_me_disabled,
          callback: () => null,
        ),
        _QuickAction(
          title: 'pages.dashboard.general.move_card.save_btn'.tr(),
          description: 'pages.dashboard.general.move_card.save_tooltip'.tr(),
          icon: Icons.save_alt,
          callback: () => null,
        ),
      ],
    ));

    return const Stream.empty();
  }

  @override
  // ignore: no-empty-block
  Future<void> onBedMesh() async {
    // Do nothing, preview does not need this
  }

  @override
  // ignore: no-empty-block
  Future<void> onBedScrewAdjust() async {
    // Do nothing, preview does not need
  }

  @override
  // ignore: no-empty-block
  Future<void> onHomeAxisBtn(Set<PrinterAxis> axis) async {
    // Do nothing, preview does not need
  }

  @override
  // ignore: no-empty-block
  Future<void> onMotorOff() async {
    // Do nothing, preview does not need
  }

  @override
  // ignore: no-empty-block
  Future<void> onMoveBtn(PrinterAxis axis, [bool positive = true]) async {
    // Do nothing, preview does not need
  }

  @override
  // ignore: no-empty-block
  Future<void> onProbeCalibration() async {
    // Do nothing, preview does not need
  }

  @override
  // ignore: no-empty-block
  Future<void> onQuadGantry() async {
    // Do nothing, preview does not need
  }

  @override
  // ignore: no-empty-block
  Future<void> onSaveConfig() async {
    // Do nothing, preview does not need
  }

  @override
  // ignore: no-empty-block
  Future<void> onScrewTiltCalc() async {
    // Do nothing, preview does not need
  }

  @override
  void onSelectedChanged(int? index) {
    state = state.whenData((value) => value.copyWith(selected: index ?? 0));
  }

  @override
  // ignore: no-empty-block
  Future<void> onZEndstopCalibration() async {
    // Do nothing, preview does not need
  }

  @override
  // ignore: no-empty-block
  Future<void> onZTiltAdjust() async {
    // Do nothing, preview does not need
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
