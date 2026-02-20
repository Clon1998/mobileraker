/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/machine/gcode_macro.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/selection_bottom_sheet.dart';
import 'package:mobileraker/ui/components/tool_channel_selector/active_tool_channel.dart';
import 'package:mobileraker/ui/components/tool_channel_selector/no_tool_selected.dart';
import 'package:mobileraker/ui/components/tool_channel_selector/skeleton_tool_channel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'macro_tool_selector.freezed.dart';
part 'macro_tool_selector.g.dart';

RegExp _toolchangeMacroRegex = RegExp(r'^T\d+$');
RegExp _toolheadParkingMacroRegex = RegExp(r'^PARK_(TOOLHEAD|EXTRUDER)$');

class MacroToolSelector extends ConsumerWidget {
  const MacroToolSelector({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncGuard(
      // debugLabel: 'MacroToolSelector-$machineUUID',
      toGuard: _macroToolSelectorControllerProvider(machineUUID).selectAs((d) => true),
      childOnData: _DataMacroToolSelector(machineUUID: machineUUID),
      childOnLoading: SkeletonToolChannel(),
    );
  }
}

class _DataMacroToolSelector extends ConsumerWidget {
  const _DataMacroToolSelector({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_macroToolSelectorControllerProvider(machineUUID).notifier);
    final model = ref.watch(_macroToolSelectorControllerProvider(machineUUID)).requireValue;

    final NumberFormat numberFormat = NumberFormat('0.0', context.locale.toStringWithSeparator());

    // Btw for idex (Rat 4) this wont happen. We always have one that is active!
    if (model.activeTool == null) {
      return NoToolSelected(onTap: controller.onSelectTool.only(model.klippyCanReceiveCommands));
    }
    final (activeTool, extruderInfo) = model.activeTool!;
    String? subtitle = numberFormat.format(extruderInfo.temperature);
    if (extruderInfo.target > 0) {
      subtitle += '/${numberFormat.format(extruderInfo.target)}';
    }
    subtitle += ' °C';

    return ActiveToolChannel(
      name: activeTool.name,
      subtitle: subtitle,
      color: _getColorFromMacro(activeTool),
      onTap: controller.onSelectTool.only(model.klippyCanReceiveCommands),
    );
  }
}

@riverpod
class _MacroToolSelectorController extends _$MacroToolSelectorController {
  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  @override
  Future<_Model> build(String machineUUID) async {
    final printerF = ref.watch(printerProvider(machineUUID).future);
    final klipperF = ref.watch(klipperProvider(machineUUID).future);

    final (printer, klipper) = await (printerF, klipperF).wait;

    final availableTools = printer.gcodeMacros.values
        .where((e) => _toolchangeMacroRegex.hasMatch(e.name))
        .sortedByCompare((e) => int.tryParse(e.name.substring(1)) ?? 0, (i, j) => i.compareTo(j));

    final parkMacro = printer.gcodeMacros.values.firstWhereOrNull((e) => _toolheadParkingMacroRegex.hasMatch(e.name));

    final activeTool = availableTools.where((e) => e.vars['active'] == true).firstOrNull?.let((macro) {
      final extruder = int.tryParse(macro.name.substring(1))?.let(printer.extruders.elementAtOrNull);
      if (extruder == null) return null;
      return (macro, extruder);
    });

    return _Model(
      klippyCanReceiveCommands: klipper.klippyCanReceiveCommands,
      availableTools: availableTools,
      activeTool: activeTool,
      parkMacro: parkMacro,
    );
  }

  Future<void> onSelectTool() async {
    final model = state.value;
    if (model == null) return;

    final pairs = model.availableTools.map((macro) => (macro, _tempProviderForToolMacro(macro))).toList();

    final res = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
        data: SelectionBottomSheetArgs<GcodeMacro?>(
          showSearch: false,
          options: [
            if (model.parkMacro != null)
              SelectionOption(
                value: null,
                label: tr('components.tool_channel_selector.sheet.park_toolhead'),
                subtitle: tr('components.tool_channel_selector.sheet.park_toolhead_desc'),
              ),
            for (final (macro, tempProvider) in pairs)
              SelectionOption(
                value: macro,
                horizontalTitleGap: 10,
                selected: macro.vars['active'] == true,
                label: macro.name,
                // subtitle: 'Color: ${macro.vars['color'] ?? macro.vars['colour'] ?? 'N/A'}',
                trailing: Consumer(
                  builder: (context, ref, _) {
                    final NumberFormat numberFormat = NumberFormat('0.0', context.locale.toStringWithSeparator());

                    final temp = ref.watch(tempProvider);
                    if (temp == null) return SizedBox.shrink();
                    return Tooltip(
                      message: tr('dialogs.heater_temperature.title', args: [macro.name, numberFormat.format(temp)]),
                      child: Chip(
                        side: _getColorFromMacro(macro)?.let((c) => BorderSide(color: c)),
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

    if (!res.confirmed || res.data is! GcodeMacro?) return;
    final selectedMacro = res.data as GcodeMacro?;
    if (selectedMacro == null) {
      if (model.parkMacro == null) return;
      // Park the toolhead
      await _printerService.gCode(model.parkMacro!.name);
      return;
    }

    // Activate the selected toolhead
    await _printerService.gCode(selectedMacro.name);
  }

  ProviderListenable<double?> _tempProviderForToolMacro(GcodeMacro macro) {
    final extruderIdx = int.parse(macro.name.substring(1));
    return printerProvider(
      machineUUID,
    ).selectRequireValue((p) => p.extruders.elementAtOrNull(extruderIdx)?.temperature);
  }
}

Color? _getColorFromMacro(GcodeMacro macro) {
  final Object? val = macro.vars['color'] ?? macro.vars['colour'];
  return val?.let((v) => int.tryParse(v.toString(), radix: 16))?.let((i) => Color(i | 0xFF000000));
}

@freezed
sealed class _Model with _$Model {
  const factory _Model({
    required bool klippyCanReceiveCommands,
    required List<GcodeMacro> availableTools,
    (GcodeMacro, Extruder)? activeTool,
    GcodeMacro? parkMacro,
  }) = __Model;
}
