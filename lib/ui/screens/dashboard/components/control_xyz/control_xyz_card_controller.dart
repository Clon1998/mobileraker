import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/config/config_file.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/general_tab_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'control_xyz_card_controller.freezed.dart';
part 'control_xyz_card_controller.g.dart';

@freezed
class ControlXYZState with _$ControlXYZState {
  const factory ControlXYZState({
    @Default(0) int index,
    @Default([]) List<QuickAction> directActions,
    @Default([]) List<QuickAction> moreActions,
  }) = _ControlXYZState;
}

@freezed
class QuickAction with _$QuickAction {
  const factory QuickAction({
    required String title,
    required String description,
    required IconData icon,
    required FutureOr<void>? Function()? callback,
  }) = _QuickAction;
}

@riverpod
class ControlXYZCardController extends _$ControlXYZCardController {
  @override
  ControlXYZState build() {
    return _constructInitialState();
  }

  onSelectedAxisStepSizeChanged(int index) {
    state = state.copyWith(index: index);
  }

  onMoveBtn(PrinterAxis axis, [bool positive = true]) {
    MachineSettings machineSettings =
    ref.read(selectedMachineSettingsProvider).value!;
    var printerService = ref.read(printerServiceSelectedProvider);

    double step = machineSettings.moveSteps[state.index].toDouble();
    double dirStep = (positive) ? step : -1 * step;

    switch (axis) {
      case PrinterAxis.X:
        if (machineSettings.inverts[0]) dirStep *= -1;
        printerService.movePrintHead(
            x: dirStep, feedRate: machineSettings.speedXY.toDouble());
        break;
      case PrinterAxis.Y:
        if (machineSettings.inverts[1]) dirStep *= -1;
        printerService.movePrintHead(
            y: dirStep, feedRate: machineSettings.speedXY.toDouble());
        break;
      case PrinterAxis.Z:
        if (machineSettings.inverts[2]) dirStep *= -1;
        printerService.movePrintHead(
            z: dirStep, feedRate: machineSettings.speedZ.toDouble());
        break;
      default:
        throw const MobilerakerException('Unreachable');
    }
  }

  Future<void> onHomeAxisBtn(Set<PrinterAxis> axis) async {
    await ref.read(printerServiceSelectedProvider).homePrintHead(axis);
  }

  Future<void> onQuadGantry() async {
    await ref.read(printerServiceSelectedProvider).quadGantryLevel();
  }

  Future<void> onBedMesh() async {
    await ref.read(printerServiceSelectedProvider).bedMeshLevel();
  }

  Future<void> onMotorOff() async {
    await ref.read(printerServiceSelectedProvider).m84();
  }

  Future<void> onZTiltAdjust() async {
    await ref.read(printerServiceSelectedProvider).zTiltAdjust();
  }

  Future<void> onScrewTiltCalc() async {
    await ref.read(printerServiceSelectedProvider).screwsTiltCalculate();
  }

  Future<void> onSaveConfig() async {
    await ref.read(printerServiceSelectedProvider).saveConfig();
  }

  Future<void> onProbeCalibration() async {
    await ref.read(printerServiceSelectedProvider).probeCalibrate();
  }

  Future<void> onZEndstopCalibration() async {
    await ref.read(printerServiceSelectedProvider).zEndstopCalibrate();
  }

  Future<void> onBedScrewAdjust() async {
    await ref.read(printerServiceSelectedProvider).bedScrewsAdjust();
  }

  ControlXYZState _constructInitialState() {
    ConfigFile? configFile = ref.watch(generalTabViewControllerProvider
        .select((data) => data.valueOrNull?.printerData.configFile));

    List<QuickAction> directActions = [
      QuickAction(
        title: tr('pages.dashboard.general.move_card.home_all_btn'),
        description: tr('pages.dashboard.general.move_card.home_all_tooltip'),
        icon: Icons.home,
        callback: () => onHomeAxisBtn(
          {PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z},
        ),
      ),
      if (configFile?.hasQuadGantry == true)
        QuickAction(
            title: tr('pages.dashboard.general.move_card.qgl_btn'),
            description: tr('pages.dashboard.general.move_card.qgl_tooltip'),
            icon: FlutterIcons.quadcopter_mco,
            callback: onQuadGantry),
      if (configFile?.hasBedMesh == true)
        QuickAction(
            title: tr('pages.dashboard.general.move_card.mesh_btn'),
            description: tr('pages.dashboard.general.move_card.mesh_tooltip'),
            icon: FlutterIcons.map_marker_path_mco,
            callback: onBedMesh),
      if (configFile?.hasScrewTiltAdjust == true)
        QuickAction(
          title: tr('pages.dashboard.general.move_card.stc_btn'),
          description: tr('pages.dashboard.general.move_card.stc_tooltip'),
          icon: FlutterIcons.screw_machine_flat_top_mco,
          callback: onScrewTiltCalc,
        ),
      if (configFile?.hasZTilt == true)
        QuickAction(
          title: tr('pages.dashboard.general.move_card.ztilt_btn'),
          description: tr('pages.dashboard.general.move_card.ztilt_tooltip'),
          icon: Icons.architecture,
          callback: onZTiltAdjust,
        ),
    ];

    List<QuickAction> calibrationActions = [
      if (configFile?.hasProbe == true)
        QuickAction(
          title: 'pages.dashboard.general.move_card.poff_btn'.tr(),
          description: 'pages.dashboard.general.move_card.poff_tooltip'.tr(),
          icon: FlutterIcons.grease_pencil_mco,
          callback: onProbeCalibration,
        ),
      if (configFile?.hasBedScrews == true)
        QuickAction(
          title: tr('pages.dashboard.general.move_card.bsa_btn'),
          description: tr('pages.dashboard.general.move_card.bsa_tooltip'),
          icon: FlutterIcons.axis_z_rotate_clockwise_mco,
          callback: onBedScrewAdjust,
        ),
      if (configFile?.hasVirtualZEndstop == false)
        QuickAction(
          title: 'pages.dashboard.general.move_card.zoff_btn'.tr(),
          description: 'pages.dashboard.general.move_card.zoff_tooltip'.tr(),
          icon: Icons.vertical_align_bottom,
          callback: onZEndstopCalibration,
        ),
      QuickAction(
        title: 'pages.dashboard.general.move_card.save_btn'.tr(),
        description: 'pages.dashboard.general.move_card.save_tooltip'.tr(),
        icon: Icons.save_alt,
        callback: onSaveConfig,
      ),
    ];

    var m84 = QuickAction(
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

    return ControlXYZState(
        directActions: directActions, moreActions: calibrationActions);
  }
}
