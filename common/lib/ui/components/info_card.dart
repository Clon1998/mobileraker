/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, this.child, this.title, this.leading, this.body})
      : assert(child != null || (title != null && body != null),
            'Either provide the child or the title'),
        assert(child == null || (title == null && body == null), 'Only define the child or the title and body!');
  final Widget? child;
  final Widget? title;
  final Widget? leading;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Center(
      child: Card(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        color: theme.colorScheme.secondaryContainer,
        child: child ?? _fallbackChild(theme),
      ),
    );
  }

  Widget _fallbackChild(ThemeData theme) {
    var onContainer = theme.colorScheme.onSecondaryContainer;
    return DefaultTextStyle(
      style: theme.textTheme.bodySmall?.copyWith(color: _lighten(onContainer, 5)) ?? TextStyle(color: onContainer),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
        child: Row(
          children: [
            if (leading != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: leading!,
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: theme.textTheme.titleSmall ??
                        TextStyle(
                          color: onContainer,
                          fontWeight: FontWeight.bold,
                        ),
                    child: title!,
                  ),
                  body!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Taken from flex_color_scheme, just here to avoid adding a dependency
Color _lighten(Color color, [final int amount = 10]) {
  if (amount <= 0) return color;
  if (amount > 100) return Colors.white;
  // HSLColor returns saturation 1 for black, we want 0 instead to be able
  // lighten black color up along the grey scale from black.
  final HSLColor hsl =
      color == const Color(0xFF000000) ? HSLColor.fromColor(color).withSaturation(0) : HSLColor.fromColor(color);
  return hsl.withLightness(min(1, max(0, hsl.lightness + amount / 100))).toColor();
}