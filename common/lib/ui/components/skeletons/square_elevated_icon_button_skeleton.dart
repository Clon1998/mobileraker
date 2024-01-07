/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class SquareElevatedIconButtonSkeleton extends StatelessWidget {
  const SquareElevatedIconButtonSkeleton({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    const raw = Padding(
      padding: EdgeInsets.all(2.5),
      child: SizedBox(
        width: 43,
        height: 43,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
          ),
        ),
      ),
    );
    if (margin == null) return raw;

    return Padding(
      padding: margin!,
      child: raw,
    );
  }
}
