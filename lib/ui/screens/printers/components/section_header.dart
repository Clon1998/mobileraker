/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: themeData.textTheme.labelMedium?.copyWith(color: themeData.colorScheme.secondary),
        ),
      ),
    );
  }
}
