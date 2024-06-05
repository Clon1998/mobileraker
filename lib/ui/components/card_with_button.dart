/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class CardWithButton extends StatelessWidget {
  static const double radius = 15;

  const CardWithButton({
    super.key,
    this.backgroundColor,
    required this.builder,
    required this.buttonChild,
    this.onTap,
    this.onLongTap,
  });

  final Color? backgroundColor;
  final WidgetBuilder builder;
  final Widget buttonChild;
  final VoidCallback? onTap;
  final VoidCallback? onLongTap;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    var bgColor = backgroundColor ?? themeData.colorScheme.surfaceVariant;
    var onBackgroundColor = (ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark
            ? Colors.white
                .blendAlpha(themeData.colorScheme.primary.brighten(20), 0)
            : Colors.black
                .blendAlpha(themeData.colorScheme.primary.brighten(20), 0));

    return Container(
      padding: CardTheme.of(context).margin ?? const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(radius)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              child: Theme(
                data: themeData.copyWith(
                  textTheme: themeData.textTheme.apply(
                    bodyColor: onBackgroundColor,
                    displayColor: onBackgroundColor,
                  ),
                  iconTheme: themeData.iconTheme.copyWith(color: onBackgroundColor),
                ),
                child: DefaultTextStyle(
                  style: TextStyle(color: onBackgroundColor),
                  child: Builder(builder: builder),
                ),
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              maximumSize: const Size.fromHeight(48),
              padding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(radius)),
              ),
              foregroundColor: themeData.colorScheme.onPrimary,
              backgroundColor: themeData.colorScheme.primary,
              // onPrimary: Theme.of(context).colorScheme.onSecondary,
              disabledForegroundColor: themeData.colorScheme.onPrimary.withOpacity(0.38),
            ),
            onPressed: onTap,
            onLongPress: onLongTap,
            child: buttonChild,
          ),
        ],
      ),
    );
  }
}
