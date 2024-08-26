/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_extruder.dart';
import 'package:common/data/dto/machine/gcode_macro.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/mobileraker_icon_button.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/components/skeletons/range_selector_skeleton.dart';
import 'package:common/ui/mobileraker_icons.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/single_value_selector.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../service/ui/dialog_service_impl.dart';
import '../../../components/dialog/edit_form/num_edit_form_dialog.dart';
import '../../../components/dialog/filament_operation_dialog.dart';

part 'control_extruder_card.freezed.dart';
part 'control_extruder_card.g.dart';

RegExp _toolchangeMacroRegex = RegExp(r'^T\d+$');

class ControlExtruderCard extends HookConsumerWidget {
  const ControlExtruderCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _Preview();
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();

    return AsyncGuard(
      animate: true,
      debugLabel: 'ControlExtruderCard-$machineUUID',
      toGuard: _controlExtruderCardControllerProvider(machineUUID).selectAs((value) => value.showCard),
      childOnLoading: const _ControlExtruderLoading(),
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
        _controlExtruderCardControllerProvider(_machineUUID).overrideWith(_ControlExtruderCardPreviewController.new),
      ],
      child: const ControlExtruderCard(machineUUID: _machineUUID),
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
                  SizedBox(height: 8),
                  // Loading/Unloading part
                  Divider(),
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceEvenly,
                    overflowAlignment: OverflowBarAlignment.center,
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
                        width: 24,
                        height: 24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                          ),
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
            opacity: model.activeExtruder == null || model.minExtrudeTempReached ? 0 : 1,
            duration: kThemeAnimationDuration,
            child: Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                margin: const EdgeInsets.symmetric(horizontal: 64.0),
                message: tr(
                  'pages.dashboard.control.extrude_card.cold_extrude_error',
                  args: [(model.activeExtruderConfig?.minExtrudeTemp ?? 180).toStringAsFixed(0)],
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
    final model = ref.watch(_controlExtruderCardControllerProvider(machineUUID).select((value) => value.requireValue));
    final controller = ref.watch(_controlExtruderCardControllerProvider(machineUUID).notifier);

    final canExtrude = model.minExtrudeTempReached && model.klippyCanReceiveCommands;

    final themeData = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (model.toolchangeMacros.isNotEmpty) _ToolSelector(machineUUID: machineUUID),
        LayoutBuilder(
          builder: (context, constraints) {
            final theme = Theme.of(context);

            // 24 from mobile raker icon button padding
            final icoSize = (theme.iconTheme.size ?? 24) + 24;
            final width = (constraints.maxWidth - icoSize) / 2;

            return OverflowBar(
              alignment: MainAxisAlignment.spaceEvenly,
              overflowAlignment: OverflowBarAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: width),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(MobilerakerIcons.nozzle_unload),
                        label: const Text(
                          'pages.dashboard.control.extrude_card.retract',
                        ).tr(),
                        onPressed: canExtrude ? () => controller.onMoveE(true) : null,
                      ),
                    ],
                  ),
                ),
                MobilerakerIconButton(
                  onPressed: controller.onFeedrateButtonPressed,
                  icon: const Icon(Icons.speed),
                  color: themeData.colorScheme.primary,
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: width),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(MobilerakerIcons.nozzle_load),
                        label: const Text(
                          'pages.dashboard.control.extrude_card.extrude',
                        ).tr(),
                        onPressed: canExtrude ? () => controller.onMoveE() : null,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        Text(
          '${tr('pages.dashboard.control.extrude_card.extrude_len')} [mm]',
        ),
        const SizedBox(height: 8),
        SingleValueSelector(
          selectedIndex: model.stepIndex,
          onSelected: canExtrude ? controller.onSelectedStepChanged : null,
          values: [for (var step in model.steps) step.toString()],
        ),
        const SizedBox(height: 8),
        const Divider(),
        LayoutBuilder(
          builder: (context, constraints) {
            final theme = Theme.of(context);
            final icoSize = (theme.iconTheme.size ?? 24) + 24;
            double width = (constraints.maxWidth - icoSize) / 2;

            return OverflowBar(
              alignment: MainAxisAlignment.spaceEvenly,
              overflowAlignment: OverflowBarAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: width),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AsyncOutlinedButton(
                        onPressed: controller.onUnloadFilament.only(model.klippyCanReceiveCommands),
                        child: const Text('general.unload').tr(),
                      ),
                    ],
                  ),
                ),
                MobilerakerIconButton(
                  onPressed: controller.onHeatingButtonPressed,
                  icon: const Icon(MobilerakerIcons.nozzle_heat_outline),
                  color: themeData.colorScheme.primary,
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: width),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AsyncOutlinedButton(
                        onPressed: controller.onLoadFilament.only(model.klippyCanReceiveCommands),
                        child: const Text('general.load').tr(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ToolSelector extends ConsumerWidget {
  const _ToolSelector({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_controlExtruderCardControllerProvider(machineUUID).requireValue());
    final controller = ref.watch(_controlExtruderCardControllerProvider(machineUUID).notifier);

    final theme = Theme.of(context);

    final sel = theme.useMaterial3
        ? SegmentedButton<GcodeMacro>(
            showSelectedIcon: false,
            segments: [
              for (var tool in model.toolchangeMacros) _buildButtonSegment((tool)),
            ],
            selected: model.toolchangeMacros.where((e) => e.vars['active'] == true).toSet(),
            onSelectionChanged: model.klippyCanReceiveCommands ? controller.onToolSetSelected : null,
          )
        : ToggleButtons(
            isSelected: [
              for (var tool in model.toolchangeMacros) tool.vars['active'] == true,
            ],
            onPressed: model.klippyCanReceiveCommands ? (i) => controller.onToolSelected(i) : null,
            children: [
              for (var tool in model.toolchangeMacros) _ToolItem(tool: tool),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child:
          SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const ClampingScrollPhysics(), child: sel),
    );
  }

  ButtonSegment<GcodeMacro> _buildButtonSegment(GcodeMacro tool) {
    final Object? val = tool.vars['color'] ?? tool.vars['colour'];
    final color = val?.let((t) => Color(int.parse(t.toString(), radix: 16) | 0xFF000000));

    return ButtonSegment(
      value: tool,
      label: Text(tool.name),
      icon: Icon(Icons.circle, color: color, size: 12).only(color != null),
    );
  }
}

class _ToolItem extends StatelessWidget {
  const _ToolItem({super.key, required this.tool});

  final GcodeMacro tool;

  @override
  Widget build(BuildContext context) {
    final Object? val = tool.vars['color'] ?? tool.vars['colour'];
    Color? color = switch (val) {
      String a when a.isNotEmpty => Color(int.parse(a, radix: 16) | 0xFF000000),
      int hexValue => Color(hexValue | 0xFF000000),
      _ => null,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (color != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(Icons.circle, color: color, size: 12),
          ),
        Text(tool.name),
      ],
    );
  }
}

@Riverpod(dependencies: [])
class _ControlExtruderCardController extends _$ControlExtruderCardController {
  DialogService get _dialogService => ref.read(dialogServiceProvider);

  SettingService get _settingService => ref.read(settingServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  KeyValueStoreKey get _settingsKey => CompositeKey.keyWithString(UtilityKeys.extruderStepIndex, machineUUID);

  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.keepAliveFor();
    // await Future.delayed(Duration(seconds: 5));

    logger.i('Building ControlExtruderCardController for $machineUUID');

    // The active extruder (Set via klipper/moonraker) is watched and based on it, the streams are constructed
    var activeExtruder =
        await ref.watch(printerProvider(machineUUID).selectAsync((data) => data.toolhead.activeExtruderIndex));

    var showCard =
        ref.watchAsSubject(printerProvider(machineUUID).selectAs((data) => data.print.state != PrintState.printing));

    // Below is stream code to prevent to many controller rebuilds
    var klippy = ref.watchAsSubject(klipperProvider(machineUUID));
    var steps = ref.watchAsSubject(machineSettingsProvider(machineUUID).selectAs((data) => data.extrudeSteps));
    var printer = ref.watchAsSubject(printerProvider(machineUUID));

    var initialIndex = _settingService.readInt(_settingsKey, 0);
    var initialVelocity =
        await ref.watch(machineSettingsProvider(machineUUID).selectAsync((data) => data.extrudeFeedrate.toDouble()));

    yield* Rx.combineLatest4(
      klippy,
      printer,
      steps,
      showCard,
      (a, b, c, d) {
        final velocity = state.whenData((value) => value.extruderVelocity).valueOrNull ?? initialVelocity;
        final idx = state.whenData((value) => value.stepIndex).valueOrNull ?? initialIndex.clamp(0, c.length - 1);

        return _Model(
          showCard: d,
          klippyCanReceiveCommands: a.klippyCanReceiveCommands,
          extruderCount: b.extruderCount,
          extruderIndex: activeExtruder,
          stepIndex: min(max(0, idx), c.length - 1),
          steps: c,
          toolchangeMacros: b.gcodeMacros.values.where((e) => _toolchangeMacroRegex.hasMatch(e.name)).sortedByCompare(
                (e) => int.tryParse(e.name.substring(1)) ?? 0,
                (i, j) => i.compareTo(j),
              ),
          extruderVelocity: velocity,
          activeExtruder: b.extruders[activeExtruder],
          activeExtruderConfig: b.configFile.extruderForIndex(activeExtruder)!,
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

  Future<void> onUnloadFilament() async {
    final extruderName =
        state.requireValue.extruderIndex > 0 ? 'extruder${state.requireValue.extruderIndex}' : 'extruder';

    _dialogService.show(DialogRequest(
        type: DialogType.filamentOperation,
        barrierDismissible: false,
        data: FilamentOperationDialogArgs(
          machineUUID: machineUUID,
          isLoad: false,
          extruder: extruderName,
        )));
  }

  Future<void> onLoadFilament() async {
    final extruderName =
        state.requireValue.extruderIndex > 0 ? 'extruder${state.requireValue.extruderIndex}' : 'extruder';

    _dialogService.show(DialogRequest(
        type: DialogType.filamentOperation,
        barrierDismissible: false,
        data: FilamentOperationDialogArgs(
          machineUUID: machineUUID,
          isLoad: true,
          extruder: extruderName,
        )));
  }

  void onToolSelected(int toolIdx) {
    final tool = state.requireValue.toolchangeMacros.elementAtOrNull(toolIdx);
    if (tool == null) return;
    _printerService.gCode(tool.name);
  }

  void onToolSetSelected(Set<GcodeMacro> selected) {
    if (selected.isEmpty || selected.length > 1) return;
    final tool = selected.firstOrNull;
    if (tool == null) return;
    _printerService.gCode(tool.name);
  }

  void onHeatingButtonPressed() {
    final cur = state.requireValue;
    if (cur.activeExtruder == null || cur.activeExtruderConfig == null) return;

    _dialogService
        .show(DialogRequest(
      type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
          ? DialogType.numEdit
          : DialogType.rangeEdit,
      title: tr('dialogs.heater_temperature.title', args: [beautifyName(cur.activeExtruder!.name)]),
      data: NumberEditDialogArguments(
        current: cur.activeExtruder!.target,
        min: 0,
        max: cur.activeExtruderConfig!.maxTemp ?? 150,
      ),
    ))
        .then((value) {
      if (value == null || !value.confirmed || value.data == null) return;

      num v = value.data;
      _printerService.setHeaterTemperature(cur.activeExtruder!.name, v.toInt());
    });
  }
}

class _ControlExtruderCardPreviewController extends _ControlExtruderCardController {
  @override
  Stream<_Model> build(String machineUUID) {
    state = AsyncValue.data(
      _Model(
        showCard: true,
        klippyCanReceiveCommands: true,
        extruderCount: 1,
        extruderIndex: 0,
        stepIndex: 0,
        steps: [1, 5, 10, 20, 50],
        extruderVelocity: 10,
        activeExtruder: Extruder.empty(),
        activeExtruderConfig: const ConfigExtruder(
          name: 'extruder',
          nozzleDiameter: 0.4,
          maxExtrudeOnlyDistance: 100,
          minTemp: 40,
          minExtrudeTemp: -1,
          maxTemp: 340,
          maxPower: 1,
          filamentDiameter: 1.75,
          maxExtrudeOnlyVelocity: 100,
          maxExtrudeOnlyAccel: 100,
        ),
      ),
    );

    return const Stream.empty();
  }

  @override
  void onExtruderSelected(int? idx) {
    // Do nothing preview
  }

  @override
  Future<void> onMoveE([bool isRetract = false]) async {
    // Do nothing preview
  }

  @override
  void onSelectedStepChanged(int? index) {
    state = state.whenData((value) => value.copyWith(stepIndex: index ?? 0));
  }

  @override
  void onFeedrateButtonPressed() {
    // Do nothing preview
  }

  @override
  Future<void> onUnloadFilament() async {
    // Do nothing preview
  }

  @override
  Future<void> onLoadFilament() async {
    // Do nothing preview
  }

  @override
  void onToolSelected(int toolIdx) {
    // Do nothing preview
  }

  @override
  void onHeatingButtonPressed() {}
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool showCard,
    required bool klippyCanReceiveCommands,
    @Default(1) int extruderCount,
    required int extruderIndex,
    required int stepIndex,
    required List<int> steps,
    @Default([]) List<GcodeMacro> toolchangeMacros,
    required double extruderVelocity,
    required Extruder? activeExtruder,
    required ConfigExtruder? activeExtruderConfig,
  }) = __Model;

  bool get minExtrudeTempReached =>
      activeExtruder != null &&
      activeExtruderConfig != null &&
      activeExtruder!.temperature >= activeExtruderConfig!.minExtrudeTemp;
}
