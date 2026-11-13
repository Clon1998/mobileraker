/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/update_manager/updater_info.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/sheet_row.dart';
import 'package:common/ui/components/sheet_search_header.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/updater_info_extension.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// Asks how the git repo of [updater] should be repaired. Pops with [BottomSheetResult.confirmed] holding whether a
/// hard recover was picked. Repairing is for supporters, everyone else sees the options locked.
class UpdateRecoverBottomSheet extends ConsumerWidget {
  const UpdateRecoverBottomSheet({super.key, required this.updater});

  final UpdaterInfo updater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final customColors = themeData.extension<CustomColors>();
    final isSupporter = ref.watch(canUseProFeaturesOnSelectedProvider);
    // A reset does not bring a corrupt repo back.
    final hardRecommended = updater.issue == UpdaterIssue.corrupt;

    return SheetContentScaffold(
      topBar: SheetSearchHeader(
        title: tr('bottom_sheets.update_recover.title', args: [beautifyName(updater.name)]),
        subtitle: tr('bottom_sheets.update_recover.subtitle'),
      ),
      // Scrolls if the rows do not fit (landscape, large fonts)
      body: SingleChildScrollView(
        padding: SheetRow.listPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OptionRow(
              icon: Icons.restart_alt,
              title: tr('bottom_sheets.update_recover.soft.title'),
              subtitle: tr('bottom_sheets.update_recover.soft.body'),
              recommended: !hardRecommended,
              locked: !isSupporter,
              onTap: () => context.pop(BottomSheetResult.confirmed(false)),
            ),
            SheetRow.separator(context),
            _OptionRow(
              icon: Icons.delete_outline,
              title: tr('bottom_sheets.update_recover.hard.title'),
              subtitle: tr('bottom_sheets.update_recover.hard.body'),
              color: customColors?.danger ?? Colors.red,
              recommended: hardRecommended,
              locked: !isSupporter,
              onTap: () => context.pop(BottomSheetResult.confirmed(true)),
            ),
            if (!isSupporter)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 28, 0),
                child: SupporterOnlyFeature(text: const Text('bottom_sheets.update_recover.supporter').tr()),
              ),
          ],
        ),
      ),
    );
  }
}

/// Icon, title and description in a [SheetRow], like the rows of the printer actions sheet. [color] tints the icon and
/// title of the risky option, a [locked] option can not be picked.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.recommended,
    required this.locked,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool recommended;
  final bool locked;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final success = themeData.extension<CustomColors>()?.success ?? Colors.green;
    final tint = locked ? themeData.disabledColor : color;

    return SheetRow(
      onTap: locked ? null : onTap,
      child: Row(
        children: [
          Icon(icon, color: tint ?? colorScheme.onSurfaceVariant),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: themeData.textTheme.titleMedium?.copyWith(color: tint),
                      ),
                    ),
                    if (recommended) ...[
                      const Gap(8),
                      Text(
                        'bottom_sheets.update_recover.recommended',
                        style: themeData.textTheme.labelSmall?.copyWith(color: success, fontWeight: FontWeight.bold),
                      ).tr(),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: themeData.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (locked) ...[const Gap(12), Icon(Icons.lock_outline, size: 20, color: colorScheme.onSurfaceVariant)],
        ],
      ),
    );
  }
}
