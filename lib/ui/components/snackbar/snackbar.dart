/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:stringr/stringr.dart';

class MobilerakerSnackbar extends StatelessWidget {
  const MobilerakerSnackbar({
    super.key,
    required this.config,
    this.onDismissed,
  });

  final SnackBarConfig config;

  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);

    var colConf = _colorConfig(themeData);

    return InkWell(
      onTap: onDismissed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.title ?? config.type.name.titleCase(),
                    style: themeData.textTheme.titleLarge?.copyWith(
                      color: colConf.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    config.message ?? '',
                    style: TextStyle(color: colConf.foreground),
                  ),
                ],
              ),
            ),
            if (config.mainButtonTitle != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colConf.buttonBackground,
                  foregroundColor: colConf.buttonForeground,
                ),
                onPressed: config.onMainButtonTapped != null
                    ? () {
                        if (config.closeOnMainButtonTapped == true && onDismissed != null) {
                          onDismissed!();
                        }
                        config.onMainButtonTapped!();
                      }
                    : null,
                child: Text(config.mainButtonTitle!),
              ),
          ],
        ),
      ),
    );
  }

  ({Color background, Color buttonBackground, Color buttonForeground, Color foreground}) _colorConfig(
    ThemeData themeData,
  ) {
    return switch (config.type) {
      SnackbarType.error => (
          background: Colors.red,
          foreground: Colors.white70,
          buttonBackground: Colors.red.darken(22),
          buttonForeground: Colors.white70,
        ),
      SnackbarType.warning => (
          background: Colors.deepOrange,
          foreground: Colors.white70,
          buttonBackground: Colors.deepOrange.darken(11),
          buttonForeground: Colors.white70,
        ),
      _ => (
          background: themeData.colorScheme.tertiaryContainer,
          foreground: themeData.colorScheme.onTertiaryContainer,
          buttonBackground: themeData.colorScheme.primary,
          buttonForeground: themeData.colorScheme.onPrimary,
        ),
    };
  }
}
