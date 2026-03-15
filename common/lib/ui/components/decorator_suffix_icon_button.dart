/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/object_extension.dart';
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
        child: Icon(icon, size: 18, color: Theme.of(context).disabledColor.only(onPressed == null),),
      ),
    );
  }
}
