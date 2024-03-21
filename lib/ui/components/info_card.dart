/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flex_color_scheme/flex_color_scheme.dart';
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
      style:
          theme.textTheme.bodySmall?.copyWith(color: onContainer.lighten(5)) ??
              TextStyle(color: onContainer),
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
