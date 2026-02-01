/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/print_task_config.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/selection_bottom_sheet.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'active_tool_channel.dart';
import 'no_tool_selected.dart';
import 'operation_tool_channel.dart';
import 'skeleton_tool_channel.dart';

part 'u1_tool_selector.freezed.dart';
part 'u1_tool_selector.g.dart';

class U1ToolSelector extends ConsumerWidget {
  const U1ToolSelector({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncGuard(
      // debugLabel: 'U1ToolSelector-$machineUUID',
      toGuard: _u1ToolSelectorControllerProvider(machineUUID).selectAs((d) => true),
      childOnLoading: SkeletonToolChannel(),
      childOnData: _DataU1ToolSelector(machineUUID: machineUUID),
    );
  }
}

class _DataU1ToolSelector extends ConsumerWidget {
  const _DataU1ToolSelector({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_u1ToolSelectorControllerProvider(machineUUID).notifier);
    final model = ref.watch(_u1ToolSelectorControllerProvider(machineUUID)).requireValue;

    final NumberFormat numberFormat = NumberFormat('0.0', context.locale.toStringWithSeparator());

    if ((model.parkingTool ?? model.pickingTool) != null) {
      final isParking = model.parkingTool != null;
      final tool = (model.parkingTool ?? model.pickingTool)!;
      return OperationToolChannel(
        name: 'T${tool.num} - ${model.printTaskConfig.filamentType.elementAt(tool.num)}',
        operation: isParking
            ? tr('components.tool_channel_selector.operating.parking_toolhead')
            : tr('components.tool_channel_selector.operating.picking_toolhead'),
        color: Color(model.printTaskConfig.filamentColor.elementAt(tool.num)),
        prefix: 'T${tool.num}',
        isChannel: false,
      );
    }

    final activeTool = model.activeTool;
    if (activeTool == null) {
      return NoToolSelected(onTap: controller.onSelectTool.only(model.klippyCanReceiveCommands));
    }

    String? subtitle = numberFormat.format(activeTool.temperature);
    if (activeTool.target > 0) {
      subtitle += '/${numberFormat.format(activeTool.target)}';
    }
    subtitle += ' °C';

    return ActiveToolChannel(
      prefix: 'T${activeTool.num}',
      name: 'T${activeTool.num} - ${model.printTaskConfig.filamentType.elementAt(activeTool.num)}',
      subtitle: subtitle,
      color: Color(model.printTaskConfig.filamentColor.elementAt(activeTool.num)),
      onTap: controller.onSelectTool,
    );
  }
}

@riverpod
class _U1ToolSelectorController extends _$U1ToolSelectorController {
  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  @override
  Future<_Model> build(String machineUUID) async {
    final printerF = ref.watch(printerProvider(machineUUID).future);
    final klipperF = ref.watch(klipperProvider(machineUUID).future);



    final (printer, klipper) = await (printerF, klipperF,).wait;


    final activeTool = printer.extruders.firstWhereOrNull((e) => e.state == U1ExtruderState.activate);

    return _Model(
      extruders: printer.extruders,
      klippyCanReceiveCommands: klipper.klippyCanReceiveCommands,
      // We KNOW we have one here for U1
      printTaskConfig: printer.printTaskConfig!,
      activeTool: activeTool,
      parkingTool: state.value?.parkingTool?.onlyLet((t) => t.num == activeTool?.num),
      pickingTool: state.value?.pickingTool?.onlyLet((t) => t.num != activeTool?.num),
    );
  }

  Future<void> onSelectTool() async {
    final model = state.value;
    if (model == null) return;

    final extruders = model.extruders.map(
      (e) => (e, printerProvider(machineUUID).selectRequireValue((d) => d.extruders.elementAt(e.num).temperature)),
    );

    final res = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
        data: SelectionBottomSheetArgs<Extruder?>(
          showSearch: false,
          options: [
            if (model.activeTool != null)
              SelectionOption(
                value: null,
                label: tr('components.tool_channel_selector.sheet.park_toolhead'),
                subtitle: tr('components.tool_channel_selector.sheet.park_toolhead_desc'),
              ),
            for (final (extruder, tempProvider) in extruders)
              SelectionOption(
                value: extruder,
                horizontalTitleGap: 10,
                selected: extruder.state == U1ExtruderState.activate,
                // TODO: localize states
                label: 'T${extruder.num} - ${extruder.state!.displayName}',
                subtitle: _filamentForTool(model.printTaskConfig, extruder.num),
                trailing: Consumer(
                  builder: (context, ref, _) {
                    final NumberFormat numberFormat = NumberFormat('0.0', context.locale.toStringWithSeparator());
                    final temp = ref.watch(tempProvider);
                    return Tooltip(
                      message: tr(
                        'dialogs.heater_temperature.title',
                        args: ['T${extruder.num}', numberFormat.format(temp)],
                      ),
                      child: Chip(
                        side: BorderSide(
                          color: Color(model.printTaskConfig.filamentColor.elementAt(extruder.num)),
                          width: 3,
                        ),
                        visualDensity: VisualDensity.compact,
                        label: Text('${numberFormat.format(temp)} °C'),
                        deleteIcon: Icon(FlutterIcons.temperature_celsius_mco),
                      ),
                    );
                  },
                ),
              ),
          ],
          title: const Text('components.tool_channel_selector.sheet.select_toolhead').tr(),
        ),
      ),
    );

    if (!res.confirmed || res.data is! Extruder?) return;

    final targetTool = res.data as Extruder?;

    // Required due to some riverpod bug when refreshing the state!
    final printerService = _printerService;
    // We could directly call PICK, however doing it like that we can issue states for UI to show parking -> picking
    if (model.activeTool != null) {
      // We do need to set a target here also. Why? There can be a time between finishing the parking and starting the picking, where active = null, picking = null and target = null -> "NO TOOL SELECTED" will be shown
      state = state.whenData((m) => m.copyWith(parkingTool: model.activeTool, pickingTool: targetTool));
      await printerService.gCode('PARK_${model.activeTool!.name}');
    }
    if (targetTool == null) return; // No further action needed

    // Activate the selected toolhead
    talker.info('Selecting tool: T${targetTool.num}');
    state = state.whenData((m) => m.copyWith(pickingTool: targetTool));
    await printerService.gCode('PICK_${targetTool.name}');
    // This can be used to prevent showing "NO TOOL SELECTED" during tool change
    talker.info('DONE selecting tool!!!');
  }

  String _filamentForTool(PrintTaskConfig printTaskConfig, int toolNum) {
    final filamentVendor = printTaskConfig.filamentVendor.elementAt(toolNum);
    final filamentSubType = printTaskConfig.filamentSubType.elementAt(toolNum);
    final filamentType = printTaskConfig.filamentType.elementAt(toolNum);
    return '$filamentVendor – $filamentSubType-$filamentType'.trim();
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required bool klippyCanReceiveCommands,
    required PrintTaskConfig printTaskConfig,
    required List<Extruder> extruders,
    Extruder? activeTool,
    Extruder? parkingTool,
    Extruder? pickingTool,
  }) = __Model;
}
