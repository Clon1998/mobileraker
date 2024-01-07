/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class DecoratorSuffixIconButton extends StatelessWidget {
  const DecoratorSuffixIconButton({super.key, required this.icon, this.onPressed});

  final IconData icon;
  final GestureTapCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        onTap: onPressed,
        child: Icon(icon, size: 18),
      ),
    );
  }
}
