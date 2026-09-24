/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';

class PrinterGroupEditPage extends HookConsumerWidget {
  const PrinterGroupEditPage({super.key, this.group});

  final PrinterGroup? group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = group != null;
    final nameController = useTextEditingController(text: group?.name);
    final name = useState(group?.name ?? '');
    final selected = useState<Set<String>>(group?.machineUUIDs.toSet() ?? {});
    final presets = useState<List<GroupPreset>>(group?.presets ?? []);
    final allMachines = ref.watch(allMachinesProvider).value ?? const <Machine>[];

    final canSave = name.value.trim().isNotEmpty && selected.value.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'pages.printer_groups.edit_title' : 'pages.printer_groups.create_title').tr(),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _onDelete(context, ref, group!),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: nameController,
                onChanged: (v) => name.value = v,
                decoration: InputDecoration(
                  labelText: tr('pages.printer_groups.name_field_label'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'pages.printer_groups.presets_title',
                      style: Theme.of(context).textTheme.titleMedium,
                    ).tr(),
                  ),
                  TextButton.icon(
                    onPressed: () => presets.value = [
                      ...presets.value,
                      GroupPreset.create(name: tr('pages.printer_edit.presets.new_preset')),
                    ],
                    icon: const Icon(Icons.add),
                    label: const Text('general.add').tr(),
                  ),
                ],
              ),
            ),
            if (presets.value.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: const Text('pages.printer_edit.presets.no_presets').tr(),
              ),
            for (final preset in presets.value)
              _GroupPresetTile(
                key: ValueKey(preset.uuid),
                preset: preset,
                onChanged: (updated) => presets.value = [
                  for (final p in presets.value) if (p.uuid == preset.uuid) updated else p,
                ],
                onRemove: () => presets.value = presets.value.where((p) => p.uuid != preset.uuid).toList(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'pages.printer_groups.select_machines_hint',
                style: Theme.of(context).textTheme.bodyMedium,
              ).tr(),
            ),
            for (final machine in allMachines)
              CheckboxListTile(
                value: selected.value.contains(machine.uuid),
                onChanged: (v) {
                  final next = {...selected.value};
                  if (v == true) {
                    next.add(machine.uuid);
                  } else {
                    next.remove(machine.uuid);
                  }
                  selected.value = next;
                },
                title: Text(machine.name),
                subtitle: Text(machine.httpUri.host, maxLines: 1, overflow: TextOverflow.ellipsis),
                secondary: MachineStateIndicator(machine),
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  canSave ? () => _onSave(context, ref, name.value.trim(), selected.value, presets.value) : null,
              child: const Text('general.save').tr(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSave(
    BuildContext context,
    WidgetRef ref,
    String name,
    Set<String> machineUUIDs,
    List<GroupPreset> presets,
  ) async {
    final effective = group?.copyWith(name: name, machineUUIDs: machineUUIDs.toList(), presets: presets) ??
        PrinterGroup.create(name: name, machineUUIDs: machineUUIDs.toList(), presets: presets);

    await ref.read(printerGroupServiceProvider).save(effective);
    if (context.mounted) context.pop();
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref, PrinterGroup group) async {
    final dialogService = ref.read(dialogServiceProvider);
    final result = await dialogService.showDangerConfirm(
      title: tr('pages.printer_groups.delete_dialog.title'),
      body: tr('pages.printer_groups.delete_dialog.body', args: [group.name]),
      actionLabel: tr('general.delete'),
    );

    if (result?.confirmed == true) {
      await ref.read(printerGroupServiceProvider).delete(group);
      if (context.mounted) context.pop();
    }
  }
}

class _GroupPresetTile extends HookWidget {
  const _GroupPresetTile({super.key, required this.preset, required this.onChanged, required this.onRemove});

  final GroupPreset preset;
  final ValueChanged<GroupPreset> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final nameController = useTextEditingController(text: preset.name);
    final extruderController = useTextEditingController(text: preset.extruderTemp.toString());
    final bedController = useTextEditingController(text: preset.bedTemp.toString());
    final gcodeController = useTextEditingController(text: preset.customGCode);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        title: Text(preset.name.isEmpty ? tr('pages.printer_edit.presets.new_preset') : preset.name),
        subtitle: Text('${preset.extruderTemp}°C / ${preset.bedTemp}°C'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: tr('pages.printer_edit.general.displayname'),
              suffixIcon: IconButton(icon: const Icon(Icons.delete), onPressed: onRemove),
            ),
            onChanged: (v) => onChanged(preset.copyWith(name: v)),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: extruderController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('pages.printer_edit.presets.hotend_temp'),
                    suffixText: '°C',
                  ),
                  onChanged: (v) => onChanged(preset.copyWith(extruderTemp: int.tryParse(v) ?? 0)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: bedController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('pages.printer_edit.presets.bed_temp'),
                    suffixText: '°C',
                  ),
                  onChanged: (v) => onChanged(preset.copyWith(bedTemp: int.tryParse(v) ?? 0)),
                ),
              ),
            ],
          ),
          TextField(
            controller: gcodeController,
            decoration: InputDecoration(
              labelText: tr('pages.printer_edit.presets.custom_gcode'),
              helperText: tr('pages.printer_edit.presets.custom_gcode_helper'),
              helperMaxLines: 3,
            ),
            keyboardType: TextInputType.multiline,
            minLines: 1,
            maxLines: 5,
            onChanged: (v) => onChanged(preset.copyWith(customGCode: v.trim().isEmpty ? null : v.trim())),
          ),
        ],
      ),
    );
  }
}
