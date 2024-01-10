/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class RangeSelectorSkeleton extends StatelessWidget {
  const RangeSelectorSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: ToggleButtons(
        isSelected: List.filled(itemCount, false),
        children: List.filled(
          itemCount,
          const SizedBox(
            height: 19,
            width: 38,
          ),
        ),
      ),
    );
  }
}
