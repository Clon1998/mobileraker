/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/data/dto/machine/bed_mesh/bed_mesh_profile.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
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
import 'package:mobileraker/ui/components/bed_mesh/bed_mesh_legend.dart';
import 'package:mobileraker/ui/components/bed_mesh/bed_mesh_plot.dart';
import 'package:mobileraker/ui/components/bottomsheet/bed_mesh_settings_sheet.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../service/ui/bottom_sheet_service_impl.dart';

part 'bed_mesh_card.freezed.dart';
part 'bed_mesh_card.g.dart';

class BedMeshCard extends HookConsumerWidget {
  const BedMeshCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview();
  }

  final String machineUUID;

  CompositeKey get _hadMeshKey => CompositeKey.keyWithString(UiKeys.hadMeshView, machineUUID);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    logger.i('Rebuilding bed mesh card.');
    var hadBedMesh = ref.read(boolSettingProvider(_hadMeshKey));

    return AsyncGuard(
      animate: true,
      debugLabel: 'BedMeshCard-$machineUUID',
      toGuard: _controllerProvider(machineUUID).selectAs((value) => value.hasBedMesh),
      childOnLoading: hadBedMesh ? const _BedMeshLoading() : null,
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
        _controllerProvider(_machineUUID).overrideWith(_PreviewController.new),
      ],
      child: const BedMeshCard(machineUUID: _machineUUID),
    );
  }
}

class _BedMeshLoading extends StatelessWidget {
  const _BedMeshLoading({super.key});

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
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: 30,
                            height: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
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
    var controller = ref.watch(_controllerProvider(machineUUID).notifier);

    return ListTile(
      leading: const Icon(Icons.grid_4x4),
      // leading: const Icon(FlutterIcons.grid_mco),
      title: Row(children: [
        const Text('pages.dashboard.control.bed_mesh_card.title').tr(),
      ]),
      trailing: TextButton(
        onPressed: controller.onSettingsTap,
        child: const Text('pages.dashboard.control.bed_mesh_card.profiles').tr(),
      ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // return Placeholder();
    var controller = ref.watch(_controllerProvider(machineUUID).notifier);
    var model = ref.watch(_controllerProvider(machineUUID)).requireValue;

    var themeData = Theme.of(context);
    var numberFormat = NumberFormat('0.000mm', context.locale.toStringWithSeparator());

    var meshIsActive = model.bedMesh?.profileName?.isNotEmpty == true;
    var activeMeshName = model.bedMesh?.profileName ?? tr('general.none');
    var valueRange = model.showProbed ? model.bedMesh!.zValueRangeProbed : model.bedMesh!.zValueRangeMesh;

    var range = numberFormat.format((valueRange.$2 - valueRange.$1));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (meshIsActive)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Tooltip(
                  message: activeMeshName,
                  child: Text(
                    activeMeshName,
                    style: themeData.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: tr('pages.dashboard.control.bed_mesh_card.range_tooltip'),
                child: Chip(
                  label: Text(range),
                  avatar: const Icon(
                    FlutterIcons.unfold_less_horizontal_mco,
                    // FlutterIcons.flow_line_ent,
                    // color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        if (model.canRender)
          IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (meshIsActive) ...[
                  Column(
                    children: [
                      Expanded(
                        child: BedMeshLegend(
                          valueRange:
                              model.showProbed ? model.bedMesh!.zValueRangeProbed : model.bedMesh!.zValueRangeMesh,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: controller.changeMode,
                        child: Tooltip(
                          message: tr(
                            'pages.dashboard.control.bed_mesh_card.showing_matrix',
                            gender: model.showProbed ? 'probed' : 'mesh',
                          ),
                          child: AnimatedSwitcher(
                            duration: kThemeAnimationDuration,
                            child: (model.showProbed
                                ? Icon(
                                    Icons.blur_on,
                                    key: const ValueKey('probed'),
                                    size: 30,
                                    color: themeData.colorScheme.secondary,
                                  )
                                : Icon(
                                    Icons.grid_on,
                                    key: const ValueKey('mesh'),
                                    size: 30,
                                    color: themeData.colorScheme.secondary,
                                  )),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: BedMeshPlot(
                    bedMesh: model.bedMesh,
                    bedMin: model.bedMin,
                    bedMax: model.bedMax,
                    isProbed: model.showProbed,
                  ),
                ),
                // _GradientLegend(machineUUID: machineUUID),
                // _ScaleIndicator(gradient: invertedGradient, min: zMin, max: zMax),
              ],
            ),
          ),
        if (!model.canRender)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'bottom_sheets.bedMesh.cant_render',
                textAlign: TextAlign.center,
                style: themeData.textTheme.bodySmall,
              ).tr(),
            ),
          ),
      ],
    );
  }
}

@riverpod
class _Controller extends _$Controller {
  PrinterService get _printerService => ref.read(printerServiceSelectedProvider);

  SettingService get _settingService => ref.read(settingServiceProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.meshViewMode, machineUUID);

  CompositeKey get _hadMeshKey => CompositeKey.keyWithString(UiKeys.hadMeshView, machineUUID);

  bool? _wroteValue;

  @override
  Future<_Model> build(String machineUUID) async {
    ref.keepAliveFor();

    // await Future.delayed(const Duration(milliseconds: 2000));

    var showProbed = ref.watch(boolSettingProvider(_settingsKey));

    var klippyCanReceiveCommandsF = ref.watch(
      klipperProvider(machineUUID).selectAsync((value) => value.klippyCanReceiveCommands),
    );
    var bedMeshF = ref.watch(
      printerProvider(machineUUID).selectAsync((value) => value.bedMesh),
    );
    var configFileF = ref.watch(
      printerProvider(machineUUID).selectAsync((value) => value.configFile),
    );

    var results = await Future.wait([klippyCanReceiveCommandsF, bedMeshF, configFileF]);

    var mesh = results[1] as BedMesh?;
    ConfigFile configFile = results[2] as ConfigFile;
    var showCard = mesh != null;

    if (_wroteValue != showCard) {
      _settingService.writeBool(_hadMeshKey, showCard);
      _wroteValue = showCard;
    }

    return _Model(
      canRender: configFile.stepperX != null && configFile.stepperY != null,
      klippyCanReceiveCommands: results[0] as bool,
      showProbed: showProbed,
      bedMesh: mesh,
      bedMin: (configFile.minX, configFile.minY),
      bedMax: (configFile.maxX, configFile.maxY),
    );
  }

  onSettingsTap() {
    // TODO : Make this safer and not use requireValue and !
    state.whenData((value) async {
      if (value.bedMesh == null) {
        logger.w('Bed mesh is null');
        return;
      }
      var result = await _bottomSheetService.show(BottomSheetConfig(
        type: SheetType.bedMeshSettings,
        isScrollControlled: true,
        data: BedMeshSettingsBottomSheetArguments(value.bedMesh!.profileName, value.bedMesh!.profiles),
      ));

      if (result.confirmed) {
        logger.i('Bed mesh settings confirmed: ${result.data}');

        var args = result.data as String?;
        // state = state.toLoading();
        if (args == null) {
          await _printerService.clearBedMeshProfile();
        } else {
          await _printerService.loadBedMeshProfile(args);
        }
      }
    });
  }

  changeMode() {
    if (state case AsyncValue(hasValue: true, :final value?)) {
      var mode = !value.showProbed;
      _settingService.writeBool(_settingsKey, mode);

      state = AsyncData(value.copyWith(showProbed: mode));
    }
  }

  loadProfile(String profileName) async {
    await _printerService.loadBedMeshProfile(profileName);
  }

  clearActiveMesh() async {
    await _printerService.clearBedMeshProfile();
  }
}

class _PreviewController extends _Controller {
  @override
  Future<_Model> build(String machineUUID) {
    const model = _Model(
      canRender: true,
      klippyCanReceiveCommands: true,
      showProbed: false,
      bedMesh: BedMesh(
        profileName: 'Preview Profile',
        meshMin: (40, 40),
        meshMax: (160, 160),
        probedMatrix: [
          [-0.69, 0.43, 0.26, 0.14, 0.07],
          [-0.21, 0.01, -0.09, 0.08, -0.06],
          [-0.13, -0.11, -0.07, -0.07, -0.06],
          [-0.15, -0.10, -0.09, -0.07, -0.06],
          [-0.02, -0.10, -0.10, -0.09, -0.09]
        ],
        meshMatrix: [
          [-0.69, -0.05, 0.22, 0.44, 0.43, 0.18, -0.33, -0.06, 0.19, -0.21, 0.26, 0.16, 0.07],
          [-0.21, 0.00, 0.14, 0.45, 0.13, 0.09, -0.31, -0.07, 0.13, -0.03, 0.14, -0.06, -0.13],
          [0.01, 0.05, 0.23, 0.37, 0.02, 0.01, 0.14, 0.18, 0.10, 0.00, -0.09, 0.14, 0.05],
          [0.07, -0.02, 0.13, -0.12, -0.08, 0.14, 0.08, -0.14, -0.03, -0.05, -0.08, -0.03, 0.08],
          [-0.05, -0.04, 0.00, -0.13, -0.08, 0.06, -0.02, -0.02, 0.06, -0.05, 0.05, -0.11, -0.15],
          [-0.06, -0.01, -0.05, -0.14, -0.11, -0.09, -0.05, -0.10, 0.03, -0.13, -0.11, -0.13, -0.12],
          [0.08, -0.02, -0.07, -0.12, -0.09, -0.09, -0.10, -0.03, -0.05, -0.07, -0.09, -0.14, -0.06],
          [-0.21, -0.13, -0.05, -0.11, -0.16, -0.07, -0.08, -0.05, -0.07, -0.08, -0.11, -0.14, -0.06],
          [-0.13, -0.09, -0.05, -0.08, -0.11, -0.11, -0.03, 0.03, 0.00, -0.08, -0.13, -0.07, -0.06],
          [-0.07, -0.03, -0.06, -0.08, -0.10, -0.07, -0.03, 0.01, 0.01, -0.07, -0.11, -0.08, -0.07],
          [-0.07, -0.05, -0.05, -0.04, -0.05, -0.06, -0.08, -0.07, -0.06, -0.07, -0.06, -0.02, -0.02],
          [-0.14, -0.09, -0.07, -0.10, -0.13, -0.09, -0.08, -0.07, -0.05, -0.07, -0.09, -0.07, -0.06],
          [-0.15, -0.11, -0.10, -0.12, -0.13, -0.10, -0.09, -0.08, -0.07, -0.09, -0.10, -0.10, -0.09]
        ],
        profiles: [
          BedMeshProfile(
            name: 'Preview Profile',
            points: [
              [-0.035, -0.05, -0.0375, -0.03, -0.0075],
              [0.0025, -0.02, -0.0075, -0.005, -0.005],
              [-0.005, -0.0325, 0, -0.0075, 0.015],
              [-0.0025, -0.01, -0.0075, -0.015, 0.02],
              [-0.0175, -0.0425, -0.0275, -0.025, -0.0025]
            ],
            meshParams: BedMeshParams(
              minX: 40,
              maxX: 160,
              minY: 40,
              maxY: 160,
              xCount: 5,
              yCount: 5,
              meshXPPS: 2,
              meshYPPS: 2,
              algo: 'bicubic',
              tension: 0.2,
            ),
          )
        ],
      ),
      bedMin: (0, 0),
      bedMax: (200, 200),
    );
    state = const AsyncValue.data(model);
    return Future.value(model);
  }

  @override
  onSettingsTap() {
    // Do nothing in preview
  }

  @override
  changeMode() {
    if (state case AsyncValue(hasValue: true, :final value?)) {
      var mode = !value.showProbed;

      state = AsyncData(value.copyWith(showProbed: mode));
    }
  }

  @override
  loadProfile(String profileName) async {
    // Do nothing in preview
  }

  @override
  clearActiveMesh() async {
    // Do nothing in preview
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyCanReceiveCommands,
    required bool canRender,
    required bool showProbed,
    required BedMesh? bedMesh,
    required (double, double) bedMin, //x, y
    required (double, double) bedMax, //x,y
  }) = __Model;

  bool get hasBedMesh => bedMesh != null;
}
