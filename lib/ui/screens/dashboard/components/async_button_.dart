
/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AsyncButton extends HookConsumerWidget {
  const AsyncButton({
    Key? key,
    required this.child,
    required this.onPressed,
  })  : label = null,
        super(key: key);

  const AsyncButton.icon({
    Key? key,
    required Icon icon,
    required this.label,
    required this.onPressed,
  })  : child = icon,
        super(key: key);

  final Icon child;
  final Widget? label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var animCtrler = useAnimationController(
        duration: const Duration(seconds: 1),
        lowerBound: 0.5,
        upperBound: 1,
        initialValue: 1);
    if (onPressed == null) {
      animCtrler.repeat(reverse: true);
    } else {
      animCtrler.stop();
    }

    Widget ico;

    if (onPressed == null) {
      ico = ScaleTransition(
        scale: CurvedAnimation(parent: animCtrler, curve: Curves.elasticInOut),
        child: child,
      );
    } else {
      ico = child;
    }

    if (label == null) {
      return ElevatedButton(
        onPressed: onPressed,
        child: ico,
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: ico,
      label: label!,
    );
  }
}
