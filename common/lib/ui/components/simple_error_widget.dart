/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class SimpleErrorWidget extends StatelessWidget {
  const SimpleErrorWidget({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });
  final Widget title;
  final Widget body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DefaultTextStyle(style: themeData.textTheme.titleMedium!, child: title),
        DefaultTextStyle(textAlign: TextAlign.center, style: themeData.textTheme.bodySmall!, child: body),
        if (action != null) action!,
      ],
    );
  }
}
