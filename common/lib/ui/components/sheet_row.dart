/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

/// Row of a list sheet, like [SelectionBottomSheet]'s: on M3 rounded on the left and flush with the right edge, with a
/// faint tint (use [SheetRow.listPadding] and [SheetRow.separator] for the list). M2 rows stay flat, divided by
/// [SheetRow.separator].
class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.highlighted = false,
    this.highlightColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Tints the row, e.g. for the active entry.
  final bool highlighted;

  /// Base color of the [highlighted] tint, defaults to the primary color.
  final Color? highlightColor;

  /// Padding of a list of [SheetRow]s, including the bottom view padding.
  static EdgeInsets listPadding(BuildContext context) =>
      (Theme.of(context).useMaterial3 ? const EdgeInsets.fromLTRB(12, 12, 0, 16) : EdgeInsets.zero) +
      MediaQuery.viewPaddingOf(context).copyWith(top: 0);

  /// Between two [SheetRow]s: a gap on M3, a divider on M2.
  static Widget separator(BuildContext context) => Theme.of(context).useMaterial3
      ? const SizedBox(height: 6)
      : const Divider(height: 0, indent: 16, endIndent: 16);

  /// Padding of the row's content.
  static EdgeInsets contentPadding(BuildContext context) => Theme.of(context).useMaterial3
      ? const EdgeInsets.fromLTRB(20, 12, 24, 12)
      : const EdgeInsets.fromLTRB(16, 10, 16, 10);

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final m3 = themeData.useMaterial3;

    final background = switch ((highlighted, m3)) {
      (true, _) => (highlightColor ?? colorScheme.primary).withValues(alpha: 0.12),
      (false, true) => colorScheme.onSurface.withValues(alpha: 0.04),
      (false, false) => colorScheme.surface.withValues(alpha: 0),
    };

    return ClipRRect(
      borderRadius: m3 ? const BorderRadius.horizontal(left: Radius.circular(44)) : BorderRadius.zero,
      child: AnimatedContainer(
        duration: kThemeAnimationDuration,
        color: background,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(padding: contentPadding(context), child: child),
          ),
        ),
      ),
    );
  }
}
