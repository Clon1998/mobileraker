/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/bottomsheet/confirmation_bottom_sheet.dart';
import 'package:common/ui/components/sheet_row.dart';
import 'package:common/ui/components/sheet_search_header.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/experimental/mutation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

final _actions = Mutation();

/// Index of the first firmware/host action in the rows, the start of the second group.
const _firstPowerAction = 2;

/// Printer actions while not printing: the services and job queue sheets, then the firmware and host power actions.
/// The power actions ask for confirmation, a long press skips it.
class NonPrintingBottomSheet extends ConsumerWidget {
  const NonPrintingBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final customColors = themeData.extension<CustomColors>();
    final machineName = ref.watch(selectedMachineProvider).value?.name;

    void action(String type) {
      HapticFeedback.selectionClick();
      _actions.run(ref, (tsx) => onPressButton(tsx, type));
    }

    void skipConfirm(String type) {
      HapticFeedback.vibrate();
      _actions.run(ref, (tsx) => onPressButton(tsx, type, false));
    }

    final rows = [
      _ActionRow(
        icon: Icons.miscellaneous_services_outlined,
        title: tr('bottom_sheets.non_printing.manage_service.title'),
        subtitle: tr('bottom_sheets.non_printing.manage_service.description'),
        opensSheet: true,
        onTap: () => context.pushNamed(SheetType.manageMachineServices.name),
      ),
      _ActionRow(
        icon: Icons.queue_outlined,
        title: tr('pages.paywall.benefits.job_queue_perk.title'),
        subtitle: tr('bottom_sheets.non_printing.job_queue.description'),
        opensSheet: true,
        onTap: () => ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: ProSheetType.jobQueueMenu)),
      ),
      _ActionRow(
        icon: Icons.memory,
        title: '${tr('general.firmware')} ${tr('@.lower:general.restart')}',
        subtitle: tr('bottom_sheets.non_printing.fw_restart.description'),
        onTap: () => action('fw_restart'),
        onLongPress: () => skipConfirm('fw_restart'),
      ),
      _ActionRow(
        icon: Icons.restart_alt,
        title: tr('bottom_sheets.non_printing.host_restart.title'),
        subtitle: tr('bottom_sheets.non_printing.host_restart.description'),
        color: customColors?.warning ?? Colors.orange,
        onTap: () => action('pi_restart'),
        onLongPress: () => skipConfirm('pi_restart'),
      ),
      _ActionRow(
        icon: Icons.power_settings_new,
        title: tr('bottom_sheets.non_printing.host_shutdown.title'),
        subtitle: tr('bottom_sheets.non_printing.host_shutdown.description'),
        color: customColors?.danger ?? Colors.red,
        onTap: () => action('pi_shutdown'),
        onLongPress: () => skipConfirm('pi_shutdown'),
      ),
    ];

    return SheetContentScaffold(
      topBar: SheetSearchHeader(title: tr('bottom_sheets.non_printing.title'), subtitle: machineName),
      // Scrolls if the rows do not fit (landscape, large fonts)
      body: SingleChildScrollView(
        padding: SheetRow.listPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, row) in rows.indexed) ...[
              // The sheets to open, then the firmware/host actions
              if (i == _firstPowerAction)
                SheetRow.groupSeparator(context)
              else if (i > 0)
                SheetRow.separator(context),
              row,
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                tr('bottom_sheets.non_printing.long_press_hint'),
                textAlign: TextAlign.center,
                style: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> onPressButton(MutationTransaction tsx, String type, [bool requireConfirm = true]) async {
    final router = tsx.get(goRouterProvider);
    final klippyService = tsx.get(klipperServiceSelectedProvider);
    var performAction = !requireConfirm;

    if (requireConfirm) {
      final bottomSheetService = tsx.get(bottomSheetServiceProvider);
      final result = await bottomSheetService.show(
        BottomSheetConfig(
          type: SheetType.confirm,
          data: ConfirmationBottomSheetArgs(
            title: tr('bottom_sheets.non_printing.confirm_action.title'),
            description: tr('bottom_sheets.non_printing.confirm_action.body', gender: type),
            hint: tr('bottom_sheets.non_printing.confirm_action.hint.long_press'),
          ),
        ),
      );
      performAction = performAction || result.confirmed;
    }
    if (!performAction) return;
    switch (type) {
      case 'pi_shutdown':
        klippyService.shutdownHost();
        break;
      case 'pi_restart':
        klippyService.rebootHost();
        break;
      case 'fw_restart':
        klippyService.restartMCUs();
        break;
      default:
        talker.error('Unknown type: $type');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => router.pop());
  }
}

/// Icon, title and description in a [SheetRow]. Rows that open another sheet end in a chevron; [color] tints the icon
/// and title of the risky actions.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
    this.color,
    this.opensSheet = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final bool opensSheet;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;

    return SheetRow(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          Icon(icon, color: color ?? colorScheme.onSurfaceVariant),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: themeData.textTheme.titleMedium?.copyWith(color: color)),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: themeData.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (opensSheet) ...[const Gap(12), Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant)],
        ],
      ),
    );
  }
}
