/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:common/data/model/moonraker_db/settings/macro_group.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/bottomsheet/mobileraker_sheet.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:stringr/stringr.dart';

part 'manage_macro_group_macros_bottom_sheet.freezed.dart';
part 'manage_macro_group_macros_bottom_sheet.g.dart';

class ManageMacroGroupMacrosBottomSheet extends ConsumerWidget {
  const ManageMacroGroupMacrosBottomSheet({
    super.key,
    required this.arguments,
  });

  final ManageMacroGroupMacrosBottomSheetArguments arguments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerProvider = _manageMacroGroupMacrosControllerProvider(arguments);
    final controller = ref.watch(controllerProvider.notifier);
    final targetGrp = ref.watch(controllerProvider.select((value) => value.targetMacroGroup));
    final otherGrps = ref.watch(controllerProvider.select((value) => value.otherMacroGroups));

    final body = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      children: [
        ...List.generate(otherGrps.length, (index) {
          var grp = otherGrps.elementAtOrNull(index)!;
          return _MacroGroup(
            macroGroup: grp,
            controllerProvider: controllerProvider,
          );
        }),
      ],
    );

    // const EdgeInsets.only(top: 10, bottom: 10),
    return MobilerakerSheet(
      hasScrollable: true,
      padding: EdgeInsets.zero,
      child: SheetContentScaffold(
        appBar: _Title(targetGrp: targetGrp.name),
        body: body,
        bottomBar: StickyBottomBarVisibility(
          child: Theme(
            data: Theme.of(context).copyWith(useMaterial3: false),
            child: BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton(
                  onPressed: controller.applyMacros,
                  child: const Text('general.apply').tr(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget implements PreferredSizeWidget {
  const _Title({super.key, required this.targetGrp});

  final String targetGrp;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          visualDensity: VisualDensity.compact,
          titleAlignment: ListTileTitleAlignment.center,
          title: Text(
            'bottom_sheets.manage_macros_in_grp.title',
            style: themeData.textTheme.headlineSmall,
          ).tr(),
          subtitle: Text(
            'bottom_sheets.manage_macros_in_grp.hint',
            style: themeData.textTheme.bodySmall,
          ).tr(args: [targetGrp]),
        ),
        const Divider(height: 0),
      ],
    );
  }

  @override
  Size get preferredSize {
    return const Size.fromHeight(kToolbarHeight + 10);
  }
}

class _MacroGroup extends StatelessWidget {
  const _MacroGroup({super.key, required this.macroGroup, required this.controllerProvider});

  final MacroGroup macroGroup;
  final _ManageMacroGroupMacrosControllerProvider controllerProvider;

  @override
  Widget build(BuildContext context) {
    logger.i('Rebuilding macro group ${macroGroup.name}');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: macroGroup.name.capitalize()),
        Wrap(
          spacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (var macro in macroGroup.macros) _MacroChip(controllerProvider: controllerProvider, macro: macro),
          ],
        ),
      ],
    );
  }
}

class _MacroChip extends ConsumerWidget {
  const _MacroChip({super.key, required this.controllerProvider, required this.macro});

  final GCodeMacro macro;
  final _ManageMacroGroupMacrosControllerProvider controllerProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(controllerProvider.notifier);

    var isSelected = ref.watch(controllerProvider.select((value) => value.macroSelection.contains(macro)));
    logger.i('Rebuilding macro chip for ${macro.name} with isSelected: $isSelected');
    return FilterChip(
      visualDensity: VisualDensity.compact,
      selected: isSelected,
      label: Text(macro.beautifiedName),
      onSelected: (v) => controller.onMacroSelectionChanged(macro, v),
    );
  }
}

// This dialog should be network independent. Therfore data is passed to it!
@riverpod
class _ManageMacroGroupMacrosController extends _$ManageMacroGroupMacrosController {
  @override
  _Model build(ManageMacroGroupMacrosBottomSheetArguments dialogArguments) {
    return _Model(
      targetMacroGroup: dialogArguments.targetMacroGroup,
      otherMacroGroups: List.unmodifiable(
        dialogArguments.allMacroGroups
            .where((element) => element.macros.isNotEmpty && element.uuid != dialogArguments.targetMacroGroup.uuid)
            .map((e) => e.copyWith(
                macros: e.macros
                    .sorted((a, b) => a.beautifiedName.toLowerCase().compareTo(b.beautifiedName.toLowerCase()))))
            .toList(),
      ),
      macroSelection: List.unmodifiable(dialogArguments.targetMacroGroup.macros),
    );
  }

  onMacroSelectionChanged(GCodeMacro macro, bool value) {
    var list = state.macroSelection.toList();

    if (value) {
      state = state.copyWith(macroSelection: List.unmodifiable(list..add(macro)));
    } else {
      state = state.copyWith(macroSelection: List.unmodifiable(list..remove(macro)));
    }
  }

  applyMacros() {
    ref.read(goRouterProvider).pop(BottomSheetResult.confirmed(List.unmodifiable(state.macroSelection)));
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required MacroGroup targetMacroGroup,
    required List<MacroGroup> otherMacroGroups,
    required List<GCodeMacro> macroSelection,
  }) = __Model;
}

class ManageMacroGroupMacrosBottomSheetArguments {
  const ManageMacroGroupMacrosBottomSheetArguments({
    required this.targetMacroGroup,
    required this.allMacroGroups,
  });

  final MacroGroup targetMacroGroup;
  final List<MacroGroup> allMacroGroups;
}
