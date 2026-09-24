/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/bottomsheet/confirmation_bottom_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/selection_bottom_sheet.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';

// The whole flow (choose action -> pick group -> pick preset) is a chain of regular
// bottomSheetService.show() calls (SheetType.actions -> SheetType.selections -> SheetType.selections)
// instead of a bespoke sheet widget. Each step pops itself as soon as it's done: option taps
// self-pop by default (SelectionBottomSheetArgs without onConfirmed), and the preset picker stays
// open across a cancelled confirm dialog by pop-ing only from inside onConfirmed. Only the OUTER
// sheet's own close is deferred a frame via addPostFrameCallback — popping the sheet that empties
// the ShellRoute's nested stack races go_router's page-removal bookkeeping if done synchronously
// right after an awaited chained pop resolves (see action_bottom_sheet.dart /
// non_printing_bottom_sheet.dart for the same fix). Inner pops don't empty that stack and are safe
// as-is.
enum _GroupAction with BottomSheetAction {
  preheat('pages.overview.group_actions.preheat', Icons.local_fire_department_outlined),
  console('pages.overview.group_actions.console', Icons.terminal);

  const _GroupAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}

class GroupActionsFab extends ConsumerWidget {
  const GroupActionsFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(printerGroupsProvider).value ?? const <PrinterGroup>[];

    if (groups.isEmpty) return const SizedBox.shrink();

    return FloatingActionButton(
      child: const Icon(Icons.workspaces_outline),
      onPressed: () => _showGroupActions(ref, groups),
    );
  }

  Future<void> _showGroupActions(WidgetRef ref, List<PrinterGroup> groups) async {
    final bottomSheetService = ref.read(bottomSheetServiceProvider);
    final preheatGroups = groups.where((g) => g.hasPresets).toList();
    final canPreheat = preheatGroups.isNotEmpty;

    await bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.actions,
        data: ActionBottomSheetArgs(
          title: const Text('pages.overview.group_actions.title').tr(),
          actions: [
            canPreheat ? _GroupAction.preheat : _GroupAction.preheat.disable,
            _GroupAction.console,
          ],
          onActionSelected: (octx, action) => switch (action) {
            _GroupAction.preheat => _preheatFlow(octx, ref, bottomSheetService, preheatGroups),
            _ => _consoleFlow(octx, ref, bottomSheetService, groups),
          },
        ),
      ),
    );
  }

  Future<PrinterGroup?> _pickGroup(
    BuildContext context,
    BottomSheetService bottomSheetService,
    List<PrinterGroup> candidates,
  ) async {
    if (candidates.length == 1) return candidates.first;

    final resp = await bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
        data: SelectionBottomSheetArgs<PrinterGroup>(
          title: const Text('pages.overview.group_actions.pick_group').tr(),
          showSearch: candidates.length > 8,
          options: [
            for (final group in candidates)
              SelectionOption(
                value: group,
                label: group.name,
                subtitle: '${group.machineUUIDs.length} printers',
              ),
          ],
        ),
      ),
    );

    return resp.confirmed ? resp.data as PrinterGroup : null;
  }

  Future<void> _consoleFlow(
    BuildContext octx,
    WidgetRef ref,
    BottomSheetService bottomSheetService,
    List<PrinterGroup> groups,
  ) async {
    final group = await _pickGroup(octx, bottomSheetService, groups);
    if (group == null) return;

    final goRouter = ref.read(goRouterProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      octx.pop(BottomSheetResult.confirmed());
      goRouter.pushNamed(AppRoute.groupConsole.name, extra: group);
    });
  }

  Future<void> _preheatFlow(
    BuildContext octx,
    WidgetRef ref,
    BottomSheetService bottomSheetService,
    List<PrinterGroup> preheatGroups,
  ) async {
    final group = await _pickGroup(octx, bottomSheetService, preheatGroups);
    if (group == null) return;

    bool broadcasted;
    if (group.presets.length == 1) {
      broadcasted = await _confirmAndBroadcast(ref, group, group.presets.first);
    } else {
      final resp = await bottomSheetService.show(
        BottomSheetConfig(
          type: SheetType.selections,
          data: SelectionBottomSheetArgs<GroupPreset>(
            title: const Text('pages.overview.group_preheat.pick_preset').tr(),
            showSearch: false,
            options: [
              for (final preset in group.presets)
                SelectionOption(
                  value: preset,
                  label: preset.name,
                  subtitle: '${preset.extruderTemp}°C / ${preset.bedTemp}°C',
                ),
            ],
            // Cancelling the confirm dialog leaves this sheet open — only a *confirmed* preheat
            // pops it, so the user lands back on the preset list instead of losing their spot.
            onConfirmed: (ctx, List<dynamic> selected) async {
              if (!await _confirmAndBroadcast(ref, group, selected.first)) return;
              ctx.pop(BottomSheetResult.confirmed());
            },
          ),
        ),
      );
      broadcasted = resp.confirmed;
    }

    if (!broadcasted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => octx.pop(BottomSheetResult.confirmed()));
  }

  Future<bool> _confirmAndBroadcast(WidgetRef ref, PrinterGroup group, GroupPreset preset) async {
    final bottomSheetService = ref.read(bottomSheetServiceProvider);
    final confirmation = await bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.confirm,
        data: ConfirmationBottomSheetArgs(
          title: tr('pages.overview.group_preheat.confirm_title'),
          description: tr(
            'pages.overview.group_preheat.confirm_body',
            args: [preset.name, '${preset.extruderTemp}', '${preset.bedTemp}', group.name],
          ),
          actionLabel: tr('pages.files.gcode_file_actions.preheat'),
          // Preheating isn't destructive — skip the red danger styling ConfirmationBottomSheet
          // otherwise defaults to (used for shutdown/restart/stop-service elsewhere).
          danger: false,
        ),
      ),
    );

    if (!confirmation.confirmed) return false;

    await _broadcastPreheat(ref, group, preset);
    return true;
  }

  Future<void> _broadcastPreheat(WidgetRef ref, PrinterGroup group, GroupPreset preset) async {
    final allMachines = await ref.read(allMachinesProvider.future);
    final members = allMachines.where((m) => group.machineUUIDs.contains(m.uuid)).toList();

    var applied = 0;
    for (final machine in members) {
      final klippy = ref.read(klipperProvider(machine.uuid)).value;
      final printer = ref.read(printerProvider(machine.uuid)).value;
      final eligible = klippy?.klippyCanReceiveCommands == true &&
          printer != null &&
          !{PrintState.printing, PrintState.paused}.contains(printer.print.state);
      if (!eligible) continue;

      final printerService = ref.read(printerServiceProvider(machine.uuid));
      printerService.setHeaterTemperature('extruder', preset.extruderTemp).ignore();
      if (printer.heaterBed != null) {
        printerService.setHeaterTemperature('heater_bed', preset.bedTemp).ignore();
      }
      if (preset.customGCode?.isNotEmpty == true) {
        printerService.gCode(preset.customGCode!).ignore();
      }
      applied++;
    }

    ref.read(snackBarServiceProvider).show(
          SnackBarConfig(
            type: applied == members.length ? SnackbarType.info : SnackbarType.warning,
            message: tr('pages.overview.group_preheat.summary', args: ['$applied', '${members.length}']),
          ),
        );
  }
}
