/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class SquareElevatedIconButtonSkeleton extends StatelessWidget {
  const SquareElevatedIconButtonSkeleton({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Container(
        margin: margin,
        width: 43,
        height: 43,
        color: Colors.white,
      ),
    );
  }
}
