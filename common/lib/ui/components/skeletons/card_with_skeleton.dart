/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class CardWithSkeleton extends StatelessWidget {
  const CardWithSkeleton({super.key, this.contentTextStyles = const []});

  final List<TextStyle?> contentTextStyles;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Padding(
      padding: themeData.cardTheme.margin ?? const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
        ),
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [for (var textStyle in contentTextStyles) Text(' ', style: textStyle)],
              ),
            ),
            // Set Button
            const SizedBox(
              height: 48,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
