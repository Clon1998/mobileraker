/*
 * Copyright (c) 2023. Patrick Schmidt.
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
            decoration: InputDecoration(
              label: Container(
                width: 85,
                height: 16,
                color: Colors.white,
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
        Container(
          margin: const EdgeInsets.all(4.5),
          width: 24,
          height: 24,
          color: Colors.white,
        ),
      ],
    );
  }
}
