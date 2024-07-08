/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:common/data/model/moonraker_db/settings/macro_group.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/decorator_suffix_icon_button.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:reorderables/reorderables.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../service/ui/bottom_sheet_service_impl.dart';
import '../../../../../service/ui/dialog_service_impl.dart';
import '../../../../components/TextSelectionToolbar.dart';
import '../../../../components/async_value_widget.dart';
import '../../../../components/bottomsheet/macro_group/manage_macro_group_macros_bottom_sheet.dart';
import '../../components/section_header.dart';

part 'macro_group_list.g.dart';

class MacroGroupList extends ConsumerWidget {
  const MacroGroupList({super.key, required this.machineUUID, this.enabled = true});

  final String machineUUID;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controllerProvider = macroGroupListControllerProvider(machineUUID);
    var controller = ref.watch(controllerProvider.notifier);
    var groupCount = ref.watch(controllerProvider.selectAs((v) => v.length));
    // Listen to the list hashCode to react to list position changes!
    var hash = ref.watch(controllerProvider
        .select((v) => v.valueOrNull?.let((e) => const DeepCollectionEquality().hash(e.map((g) => g.uuid)))));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: 'pages.dashboard.control.macro_card.title'.tr(),
          trailing: TextButton.icon(
            onPressed: enabled ? controller.addMacroGroup : null,
            label: const Text('general.add').tr(),
            icon: const Icon(Icons.source_outlined),
          ),
        ),
        AsyncValueWidget(
          value: groupCount,
          data: (count) {
            if (count == 0) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Text('pages.printer_edit.macros.no_macros_found').tr(),
              );
            }

            var groups = ref.read(controllerProvider).requireValue;

            return ReorderableListView(
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              onReorder: controller.onMacroGroupReorder,
              onReorderStart: (i) {
                FocusScope.of(context).unfocus();
                controller.onMacroGroupReorderStart(i);
              },
              onReorderEnd: controller.onMacroGroupReorderEnd,
              proxyDecorator: (child, _, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext ctx, Widget? c) {
                    final double animValue = Curves.easeInOut.transform(animation.value);
                    final double elevation = lerpDouble(0, 6, animValue)!;
                    return Material(
                      type: MaterialType.transparency,
                      elevation: elevation,
                      child: c,
                    );
                  },
                  child: child,
                );
              },
              children: List.generate(
                count,
                (index) => _MacroGroup(
                  key: ValueKey(groups[index].uuid),
                  machineUUID: machineUUID,
                  groupUUID: groups[index].uuid,
                  enabled: enabled,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

//ToDo: The textField uses and validator but this validator is not checked. It would require a form key ....
class _MacroGroup extends HookConsumerWidget {
  const _MacroGroup({super.key, required this.machineUUID, required this.groupUUID, this.enabled = true});

  final String machineUUID;
  final String groupUUID;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(macroGroupListControllerProvider(machineUUID).notifier);
    (int, MacroGroup?) indexedMacroGroup = ref.watch(macroGroupListControllerProvider(machineUUID).select((data) {
      var list = data.requireValue;
      var index = list.indexWhere((e) => e.uuid == groupUUID);
      return (index, index >= 0 ? list.elementAtOrNull(index) : null);
    }))!;
    var groupIndex = indexedMacroGroup.$1;
    var macroGroup = indexedMacroGroup.$2!;
    var macros = macroGroup.macros;

    var focusNode = useFocusNode();
    var themeData = Theme.of(context);
    return Card(
      child: ExpansionTile(
        controller: ref.watch(_expansionTileControllerProvider(groupUUID)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
        onExpansionChanged: (v) {
          if (focusNode.hasFocus) focusNode.unfocus();
        },
        leading: ReorderableDragStartListener(
          enabled: enabled,
          index: groupIndex,
          child: const Icon(Icons.drag_handle),
        ),
        title: _MacroGroupTitle(
          name: macroGroup.name,
          macroCount: macros.length,
          onAddMacro: () => controller.manageMacros(macroGroup),
        ),
        children: [
          if (!macroGroup.isDefaultGroup)
            TextFormField(
              focusNode: focusNode,
              initialValue: macroGroup.name,
              contextMenuBuilder: defaultContextMenuBuilder,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'pages.printer_edit.general.displayname'.tr(),
                suffix: DecoratorSuffixIconButton(
                  icon: Icons.delete,
                  onPressed: enabled ? () => controller.removeMacroGroup(macroGroup) : null,
                ),
              ),
              enabled: enabled,
              onChanged: (s) => controller.onMacroGroupRenamed(macroGroup, s),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: FormBuilderValidators.compose([FormBuilderValidators.required()]),
            ),
          const SizedBox(height: 8),
          SectionHeader(title: tr('pages.printer_edit.macros.macros')),
          if (macros.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Text('pages.printer_edit.macros.no_macros_in_grp').tr(),
            )
          else
            ReorderableWrap(
              needsLongPressDraggable: false,
              enableReorder: enabled,
              spacing: 4.0,
              buildDraggableFeedback: (_, constraint, widget) => Material(
                type: MaterialType.transparency,
                child: Container(
                  constraints: constraint,
                  child: widget,
                ),
              ),
              onReorderStarted: (index) {
                FocusScope.of(context).unfocus();
                // ref.read(macroGroupDragginControllerProvider.notifier).onMacroReorderStarted(macroGroup);
              },
              onReorder: (a, b) => controller.onMacroInGroupReorder(macroGroup, a, b),
              onNoReorder: (a) => controller.onNoMacroInGroupReorder(macroGroup, a),
              children: macros.map((m) {
                if (m.forRemoval != null) {
                  return Tooltip(
                    message: tr('pages.printer_edit.macros.macro_removed'),
                    showDuration: const Duration(seconds: 5),
                    triggerMode: TooltipTriggerMode.tap,
                    child: ActionChip(
                      avatar: Icon(Icons.report_problem_outlined),
                      labelStyle: TextStyle(decoration: TextDecoration.lineThrough),
                      // backgroundColor: themeData.dialogBackgroundColor,
                      label: Text(m.beautifiedName),
                      // onPressed: () => controller.macroSettings(macroGroup, m),
                    ),
                  );
                }

                return ActionChip(
                  avatar: _macroAvatar(m),
                        label: Text(m.beautifiedName),
                        onPressed: () => controller.macroSettings(macroGroup, m),
                );
              }).toList(),
            ),
          // ActionChip(
          //   backgroundColor: themeData.colorScheme.primary,
          //
          //   labelStyle: TextStyle(
          //     color: themeData.colorScheme.onPrimary,
          //   ),
          //   avatar:  Icon(Icons.library_add_outlined, size: 20, color: themeData.colorScheme.onPrimary,),
          //   label: Text('Add More!'),
          //   onPressed: () => controller.manageMacros(macroGroup),
          // ),
        ],
      ),
    );
  }

  Icon? _macroAvatar(GCodeMacro macro) {
    if (!macro.visible) return const Icon(Icons.visibility_off_outlined);
    if (!macro.showWhilePrinting) return const Icon(Icons.disabled_visible_outlined);
    return null;
  }
}

class _MacroGroupTitle extends StatelessWidget {
  const _MacroGroupTitle({
    super.key,
    required this.name,
    required this.macroCount,
    this.onAddMacro,
  });

  final String name;
  final int macroCount;
  final VoidCallback? onAddMacro;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              name.isEmpty ? 'pages.printer_edit.macros.new_macro_grp'.tr() : name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ActionChip(
            avatar: const Icon(Icons.library_add_outlined, size: 20),
            onPressed: onAddMacro,
            label: Text('$macroCount'),
            backgroundColor: themeData.colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: themeData.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

@riverpod
class MacroGroupListController extends _$MacroGroupListController {
  final String _defaultGroupName = tr('pages.printer_edit.macros.default_name');

  final List<String> _beforeReorderExpandedGroups = [];

  // this might be usefull to return to the initial state if the user cancels the edit

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  @override
  Future<List<MacroGroup>> build(String machineUUID) async {
    var groups = await ref.watch(machineSettingsProvider(machineUUID).selectAsync((v) => v.macroGroups));
    return groups;
  }

  addMacroGroup() {
    state = state.whenData((value) => List.unmodifiable([...value, MacroGroup(name: _defaultGroupName, macros: [])]));
  }

  removeMacroGroup(MacroGroup macroGroup) {
    if (macroGroup.isDefaultGroup) {
      logger.w('Can not delete default group');
      return;
    }

    state = state.whenData((value) {
      var groups = value.toList()..remove(macroGroup);

      if (macroGroup.macros.isNotEmpty) {
        var defaultGrp = groups.firstWhereOrNull((element) => element.isDefaultGroup);

        groups[groups.indexOf(defaultGrp!)] = defaultGrp.copyWith(macros: [...defaultGrp.macros, ...macroGroup.macros]);
        _snackBarService.show(SnackBarConfig(
          title: tr('pages.printer_edit.macros.deleted_grp', args: [macroGroup.name]),
          message: plural('pages.printer_edit.macros.macros_to_default', macroGroup.macros.length),
        ));
      }

      return List.unmodifiable(groups);
    });
  }

  onMacroGroupReorderStart(int index) {
    logger.i('on Macro Group Reorder Start. Index: $index');
    var list = state.requireValue;
    _beforeReorderExpandedGroups.clear();

    for (var value in list) {
      if (value.uuid == list.elementAtOrNull(index)?.uuid) continue;
      var tileController = ref.read(_expansionTileControllerProvider(value.uuid));
      if (!tileController.isExpanded) continue;
      _beforeReorderExpandedGroups.add(value.uuid);
      tileController.collapse();
    }
  }

  onMacroGroupReorder(int oldIndex, int newIndex) {
    logger.i('on Macro Group Reorder. Old: $oldIndex, New: $newIndex');
    if (!state.hasValue) return;

    state = state.whenData((groups) {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      var out = groups.toList();
      MacroGroup tmp = out.removeAt(oldIndex);
      out.insert(newIndex, tmp);
      return List.unmodifiable(out);
    });
  }

  onMacroGroupReorderEnd(int index) async {
    logger.i('on Macro Group Reorder End. Index: $index');
    // Slivers/Reorderable list uses 250ms as default duration
    await Future.delayed(const Duration(milliseconds: 340));
    for (var value in _beforeReorderExpandedGroups) {
      var tileController = ref.read(_expansionTileControllerProvider(value));
      tileController.expand();
    }
  }

  onMacroGroupRenamed(MacroGroup group, String? newName) {
    logger.i('MacroGroup ${group.name} was renamed to $newName');
    state = state.whenData((value) {
      // It can happen that the onMacro fired multiple times with the same name so the macro might have already changed name lol so the index might be -1 causing a NPE
      var index = value.indexOf(group);
      if (index < 0) return value;

      return List.unmodifiable(value.toList()..[index] = group.copyWith(name: newName ?? _defaultGroupName));
    });
  }

  onMacroInGroupReorder(MacroGroup group, int oldIdx, int newIdx) {
    logger.i('on Macro In Group Reorder $oldIdx -> $newIdx');

    state = state.whenData((value) {
      var macros = group.macros.toList();

      return List.unmodifiable(value.toList()
        ..[value.indexOf(group)] = group.copyWith(
          macros: macros..insert(newIdx, macros.removeAt(oldIdx)),
        ));
    });
  }

  onNoMacroInGroupReorder(MacroGroup group, int initialIndex) {
    // ref.read(macroGroupDragginControllerProvider.notifier).onMacroReorderStopped();
  }

  Future<void> manageMacros(MacroGroup group) async {
    var arguments = ManageMacroGroupMacrosBottomSheetArguments(
      targetMacroGroup: group,
      allMacroGroups: state.requireValue,
    );

    var result = await ref
        .read(bottomSheetServiceProvider)
        .show(BottomSheetConfig(type: SheetType.manageMacroGroupMacros, data: arguments, isScrollControlled: true));

    logger.i('Got result from manageMacroGroupMacros sheet: $result');
    if (result.confirmed) {
      state = state.whenData((value) {
        List<MacroGroup> tmp = value.toList();
        var resultingMacros = (result.data as List).cast<GCodeMacro>();
        return List.unmodifiable(tmp.map((e) {
          if (e == group) return group.copyWith(macros: resultingMacros);
          return e.copyWith(
            macros: List.unmodifiable(e.macros.whereNot(resultingMacros.contains)),
          );
        }));
      });
    }
  }

  void macroSettings(MacroGroup group, GCodeMacro macro) async {
    var result = await _dialogService.show(DialogRequest(
      type: DialogType.macroSettings,
      data: macro,
    ));

    if (result?.confirmed == true) {
      state = state.whenData((value) {
        var updatedMacro = result!.data as GCodeMacro;
        var tmp = value.toList();

        logger.i('Upadting macro ${macro.name} in group ${group.name}. $macro -> $updatedMacro');

        var updatedGroup = group.copyWith(
          macros: List.unmodifiable(group.macros.toList()..[group.macros.indexOf(macro)] = updatedMacro),
        );

        tmp[tmp.indexOf(group)] = updatedGroup;

        return List.unmodifiable(tmp);
      });
    }
  }
}

@riverpod
ExpansionTileController _expansionTileController(_ExpansionTileControllerRef ref, String macroGroupUUID) {
  return ExpansionTileController();
}
