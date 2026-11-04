/*
 * Copyright (c) 2025-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ProgressTracker extends StatelessWidget {
  const ProgressTracker({super.key, required this.progress, this.color, this.leading, this.trailing});

  final double progress;
  final Color? color;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    final numberFormat = NumberFormat.percentPattern(context.locale.toStringWithSeparator());

    return Column(
      spacing: 4,
      children: [
        LinearProgressIndicator(
          value: progress,
          color: color,
          borderRadius: BorderRadius.circular(2),
          backgroundColor: themeData.colorScheme.surfaceContainerHigh,
        ),
        // Wraps instead of overflowing if leading and trailing do not fit next to each other (narrow cards). Full
        // width, so spaceBetween puts them at the edges (a Wrap shrinks to its content otherwise).
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              leading ?? const SizedBox.shrink(),
              if (trailing != null) trailing!,
              if (trailing == null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text(numberFormat.format(progress), style: themeData.textTheme.bodySmall)],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
