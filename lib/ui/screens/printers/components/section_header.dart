/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    Key? key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 16.0),
  }) : super(key: key);

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: padding,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title.toUpperCase(),
              style: themeData.textTheme.labelMedium?.copyWith(color: themeData.colorScheme.secondary),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
