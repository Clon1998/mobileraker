/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SortedFileListHeader extends ConsumerWidget {
  const SortedFileListHeader({super.key, required this.activeSortConfig, this.trailing, this.onTapSortMode});

  final SortConfiguration? activeSortConfig;

  final Widget? trailing;

  final VoidCallback? onTapSortMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelText =
        activeSortConfig != null ? tr(activeSortConfig!.mode.translation) : tr('pages.files.sort_by.sort_by');

    final themeData = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: themeData.scaffoldBackgroundColor),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: onTapSortMode,
              label: Text(labelText, style: themeData.textTheme.bodySmall?.copyWith(fontSize: 13)),
              icon: AnimatedRotation(
                duration: kThemeAnimationDuration,
                curve: Curves.easeInOut,
                turns: activeSortConfig?.kind == SortKind.ascending ? 0 : 0.5,
                child: Icon(Icons.arrow_upward, size: 16, color: themeData.textTheme.bodySmall?.color),
              ),
              iconAlignment: IconAlignment.end,
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
