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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'pages.printer_groups.select_machines_hint',
                style: Theme.of(context).textTheme.bodyMedium,
              ).tr(),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: allMachines.length,
                itemBuilder: (context, i) {
                  final machine = allMachines[i];
                  final isSelected = selected.value.contains(machine.uuid);
                  return CheckboxListTile(
                    value: isSelected,
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
                  );
                },
              ),
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
              onPressed: canSave ? () => _onSave(context, ref, name.value.trim(), selected.value) : null,
              child: const Text('general.save').tr(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSave(BuildContext context, WidgetRef ref, String name, Set<String> machineUUIDs) async {
    final effective = group?.copyWith(name: name, machineUUIDs: machineUUIDs.toList()) ??
        PrinterGroup.create(name: name, machineUUIDs: machineUUIDs.toList());

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
