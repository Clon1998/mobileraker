/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:flutter/material.dart';

class SliderOrTextInputSkeleton extends StatelessWidget {
  const SliderOrTextInputSkeleton({super.key, this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: InputDecorator(
            decoration: const InputDecoration(
              label: SizedBox(
                width: 85,
                height: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                  ),
                ),
              ),
              isCollapsed: true,
              border: InputBorder.none,
            ),
            child: Slider(
              value: value ?? Random().nextDouble(),
              onChanged: (_) {},
            ),
          ),
        ),
        // Padding(padding: EdgeInsets.all(4.5),
        // child: Icon(Icons.edit, color: Colors.white,),
        // )
        const SizedBox(
          width: 24,
          height: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
