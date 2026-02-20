/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:common/data/model/moonraker_db/settings/macro_group.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/decorator_suffix_icon_button.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/macro_group/manage_macro_group_macros_bottom_sheet.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';
import 'package:mobileraker/util/validator/custom_form_builder_validators.dart';
import 'package:reorderables/reorderables.dart';

class MacroGroupsFormField extends StatelessWidget {
  const MacroGroupsFormField({super.key, required this.name, required this.initialValue, this.onChanged});

  final String name;
  final List<MacroGroup> initialValue;
  final ValueChanged<List<MacroGroup>?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return FormBuilderField(
      name: name,
      initialValue: initialValue,
      onChanged: onChanged,
      builder: (field) {
        final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);
        final macroGroups = field.value ?? [];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionHeader(
              title: tr('pages.dashboard.control.macro_card.title'),
              trailing: TextButton.icon(
                onPressed: (() => field.didChange(
                  List.unmodifiable([
                    ...macroGroups,
                    MacroGroup(name: tr('pages.printer_edit.macros.default_name'), macros: []),
                  ]),
                )).only(enabled),
                label: const Text('general.add').tr(),
                icon: const Icon(Icons.source_outlined),
              ),
            ),
            if (macroGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Text('pages.printer_edit.macros.no_macros_found').tr(),
              ),
            if (macroGroups.isNotEmpty) _ReordableMacroGroupList(field: field),
          ],
        );
      },
    );
  }
}

class _ReordableMacroGroupList extends HookConsumerWidget {
  const _ReordableMacroGroupList({super.key, required this.field});

  final FormFieldState<List<MacroGroup>> field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomSheetService = ref.read(bottomSheetServiceProvider);
    final snackBarService = ref.read(snackBarServiceProvider);

    final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);
    final macroGroups = field.value ?? [];
    final isReordering = useValueNotifier(false);

    return ReorderableListView(
      buildDefaultDragHandles: false,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      onReorder: onReorder,
      onReorderStart: (_) {
        isReordering.value = true;
        FocusScope.of(context).unfocus();
      },
      onReorderEnd: (_) {
        Future.delayed(const Duration(milliseconds: 340)).whenComplete(() {
          if (context.mounted) isReordering.value = false;
        });
      },

      proxyDecorator: (child, _, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext ctx, Widget? c) {
            final double animValue = Curves.easeInOut.transform(animation.value);
            final double elevation = lerpDouble(0, 6, animValue)!;
            return Material(type: MaterialType.transparency, elevation: elevation, child: c);
          },
          child: child,
        );
      },
      children: [
        for (int i = 0; i < macroGroups.length; i++)
          macroGroups[i].let((grp) {
            return _MacroGroup(
              key: ValueKey(grp.uuid),
              index: i,
              macroGroup: grp,
              onChanged: onGroupChanged.only(enabled),
              onRemove: (() => onGroupRemove(grp, snackBarService)).only(enabled),
              onAddMacro: (() => onAddMacro(grp, bottomSheetService)).only(enabled),
            );
          }),
      ],
    );
  }

  void onReorder(int oldIndex, int newIndex) {
    talker.info('on Macro Group Reorder. Old: $oldIndex, New: $newIndex');

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final out = [...?field.value];
    MacroGroup tmp = out.removeAt(oldIndex);
    out.insert(newIndex, tmp);
    field.didChange(out);
  }

  void onGroupChanged(MacroGroup grp) {
    final out = [...?field.value];
    final idx = out.indexWhere((g) => g.uuid == grp.uuid);
    if (idx == -1) return;

    out[idx] = grp;
    field.didChange(out);
  }

  void onGroupRemove(MacroGroup grp, SnackBarService snackBarService) {
    final allMacroGroups = [...?field.value];
    allMacroGroups.removeWhere((g) => g.uuid == grp.uuid);

    // We get the default group and add all of the deleted groups macros to it, if there are any.
    // This way we don't loose any macros and the user can decide what to do with them
    final dIdx = allMacroGroups.indexWhere((g) => g.isDefaultGroup);
    if (dIdx >= 0 && grp.macros.isNotEmpty) {
      final defaultGroup = allMacroGroups[dIdx];
      allMacroGroups[dIdx] = defaultGroup.copyWith(macros: List.unmodifiable([...defaultGroup.macros, ...grp.macros]));
      snackBarService.show(
        SnackBarConfig(
          title: tr('pages.printer_edit.macros.deleted_grp', args: [grp.name]),
          message: plural('pages.printer_edit.macros.macros_to_default', grp.macros.length),
        ),
      );
    }

    field.didChange(List.unmodifiable(allMacroGroups));
  }

  void onAddMacro(MacroGroup grp, BottomSheetService bottomSheetService) async {
    final allMacroGroups = [...?field.value];
    var arguments = ManageMacroGroupMacrosBottomSheetArguments(targetMacroGroup: grp, allMacroGroups: allMacroGroups);

    var result = await bottomSheetService.show(
      BottomSheetConfig(type: SheetType.manageMacroGroupMacros, data: arguments),
    );

    talker.info('Got result from manageMacroGroupMacros sheet: $result');
    if (result.confirmed) {
      final resultingMacros = (result.data as List).cast<GCodeMacro>();

      final updated = List<MacroGroup>.unmodifiable([
        for (final g in allMacroGroups)
          if (g.uuid == grp.uuid)
            g.copyWith(macros: resultingMacros)
          else
            g.copyWith(macros: List.unmodifiable(g.macros.whereNot(resultingMacros.contains))),
      ]);

      field.didChange(updated);
    }
  }
}

class _MacroGroup extends HookConsumerWidget {
  const _MacroGroup({
    super.key,
    required this.index,
    required this.macroGroup,
    this.onChanged,
    this.onRemove,
    this.onAddMacro,
  });

  final int index;
  final MacroGroup macroGroup;
  final ValueChanged<MacroGroup>? onChanged;
  final VoidCallback? onRemove;

  final VoidCallback? onAddMacro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusNode = useFocusNode();
    final controller = useExpansibleController();
    final canReorder = useListenableSelector(controller, () => !controller.isExpanded);
    final macros = macroGroup.macros;

    final themeData = Theme.of(context);

    return Card(
      child: ExpansionTile(
        controller: controller,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
        onExpansionChanged: (v) {
          if (focusNode.hasFocus) focusNode.unfocus();
        },
        leading: ReorderableDragStartListener(
          index: index,
          enabled: canReorder && onChanged != null,
          child: Icon(Icons.drag_handle, color: themeData.disabledColor.unless(canReorder && onChanged != null)),
        ),
        title: _MacroGroupTitle(name: macroGroup.name, macroCount: macros.length, onAddMacro: onAddMacro),
        children: [
          if (!macroGroup.isDefaultGroup)
            FormBuilderTextField(
              name: '__internal_macro_group_${macroGroup.uuid}_name',
              focusNode: focusNode,
              enabled: onChanged != null,
              initialValue: macroGroup.name,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'pages.printer_edit.general.displayname'.tr(),
                suffix: DecoratorSuffixIconButton(icon: Icons.delete, onPressed: onRemove),
              ),
              onChanged: (s) => s?.let((d) => onChanged?.call(macroGroup.copyWith(name: d))),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: MobilerakerFormBuilderValidator.sideEffect(FormBuilderValidators.required(), sideEffect: (e) {
                if (e != null && !controller.isExpanded) {
                  Future(() => controller.expand());
                }
              }),
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
              enableReorder: onChanged != null,
              spacing: 4.0,
              buildDraggableFeedback: (_, constraint, widget) => Material(
                type: MaterialType.transparency,
                child: Container(constraints: constraint, child: widget),
              ),
              onReorderStarted: (index) {
                FocusScope.of(context).unfocus();
              },
              onReorder: onReorder,
              children: macros.map((m) {
                if (m.forRemoval != null) {
                  return Tooltip(
                    message: tr('pages.printer_edit.macros.macro_removed'),
                    showDuration: const Duration(seconds: 5),
                    triggerMode: TooltipTriggerMode.tap,
                    child: Chip(
                      avatar: Icon(Icons.report_problem_outlined),
                      labelStyle: TextStyle(decoration: TextDecoration.lineThrough),
                      backgroundColor: themeData.disabledColor,
                      label: Text(m.beautifiedName),
                    ),
                  );
                }

                return Chip(
                  avatar: Icon(Icons.visibility_outlined.only(m.visible) ?? Icons.visibility_off_outlined),
                  label: Text(m.beautifiedName),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void onReorder(int oldIdx, int newIdx) {
    talker.info('on Macro In Group Reorder $oldIdx -> $newIdx');

    final macros = [...macroGroup.macros];
    onChanged?.call(macroGroup.copyWith(macros: List.unmodifiable(macros..insert(newIdx, macros.removeAt(oldIdx)))));
  }
}

class _MacroGroupTitle extends StatelessWidget {
  const _MacroGroupTitle({super.key, required this.name, required this.macroCount, this.onAddMacro});

  final String name;
  final int macroCount;
  final VoidCallback? onAddMacro;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
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
            labelStyle: TextStyle(color: themeData.colorScheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}
