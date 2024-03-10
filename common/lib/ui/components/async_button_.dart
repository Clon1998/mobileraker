/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AsyncElevatedButton extends HookConsumerWidget {
  const AsyncElevatedButton(
      {super.key, required this.child, required this.onPressed, this.style, this.margin, this.padding, this.curve})
      : icon = null;

  const AsyncElevatedButton.icon({
    super.key,
    required Icon this.icon,
    required Widget label,
    required this.onPressed,
    this.margin,
    this.padding,
    this.style,
    this.curve,
  }) : child = label;

  factory AsyncElevatedButton.squareIcon({
    Key? key,
    required Icon icon,
    required FutureOr<void>? Function()? onPressed,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) {
    return AsyncElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(minimumSize: const Size.square(40)),
      margin: margin,
      padding: padding,
      child: icon,
    );
  }

  final Widget child;
  final Widget? icon;
  final FutureOr<void>? Function()? onPressed;
  final ButtonStyle? style;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Curve? curve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var animCtrler =
        useAnimationController(duration: const Duration(seconds: 1), lowerBound: 0.5, upperBound: 1, initialValue: 1);
    var actionRunning = useState(false);

    if (actionRunning.value) {
      animCtrler.repeat(reverse: true);
    } else {
      animCtrler.value = 1;
    }

    Widget animatedChild = ScaleTransition(
      scale: CurvedAnimation(parent: animCtrler, curve: curve ?? Curves.elasticInOut),
      child: icon ?? child,
    );

    if (padding != null) animatedChild = Padding(padding: padding!, child: animatedChild);

    var onPressedWrapped =
        onPressed != null && !actionRunning.value ? () => _onPressedWrapper(context, actionRunning, onPressed) : null;
    var btn = (icon == null)
        ? ElevatedButton(
            onPressed: onPressedWrapped,
            style: style,
            child: animatedChild,
          )
        : ElevatedButton.icon(
            style: style,
            onPressed: onPressedWrapped,
            icon: animatedChild,
            label: child,
          );
    if (margin == null) {
      return btn;
    }

    return Container(
      margin: margin,
      child: btn,
    );
  }
}

class AsyncIconButton extends HookConsumerWidget {
  const AsyncIconButton(
      {super.key, required this.icon, required this.onPressed, this.style, this.iconSize, this.tooltip, this.color});

  final Icon icon;
  final FutureOr<void>? Function()? onPressed;
  final ButtonStyle? style;
  final double? iconSize;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var animCtrler =
        useAnimationController(duration: const Duration(seconds: 1), lowerBound: 0.5, upperBound: 1, initialValue: 1);
    var actionRunning = useState(false);

    if (actionRunning.value) {
      animCtrler.repeat(reverse: true);
    } else {
      animCtrler.value = 1;
    }

    Widget ico = ScaleTransition(
      scale: CurvedAnimation(parent: animCtrler, curve: Curves.elasticInOut),
      child: icon,
    );

    var onPressedWrapped =
        onPressed != null && !actionRunning.value ? () => _onPressedWrapper(context, actionRunning, onPressed) : null;

    return IconButton(
      onPressed: onPressedWrapped,
      icon: ico,
      color: color,
      iconSize: iconSize,
      tooltip: tooltip,
    );
  }
}

class AsyncOutlinedButton extends HookConsumerWidget {
  const AsyncOutlinedButton.icon({
    super.key,
    required Icon this.icon,
    required Widget label,
    required this.onPressed,
    this.style,
  }) : child = label;

  const AsyncOutlinedButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.style,
  }) : icon = null;

  final Widget child;
  final Widget? icon;
  final FutureOr<void>? Function()? onPressed;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var animCtrler =
        useAnimationController(duration: const Duration(seconds: 1), lowerBound: 0.5, upperBound: 1, initialValue: 1);
    var actionRunning = useState(false);

    if (actionRunning.value) {
      animCtrler.repeat(reverse: true);
    } else {
      animCtrler.value = 1;
    }

    Widget animatedWidget = ScaleTransition(
      scale: CurvedAnimation(parent: animCtrler, curve: Curves.elasticInOut),
      child: icon ?? child,
    );

    var onPressedWrapped =
        onPressed != null && !actionRunning.value ? () => _onPressedWrapper(context, actionRunning, onPressed) : null;

    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressedWrapped,
        icon: animatedWidget,
        label: child,
        style: style,
      );
    }

    return OutlinedButton(
      onPressed: onPressedWrapped,
      style: style,
      child: animatedWidget,
    );
  }
}

class AsyncFilleddButton extends HookConsumerWidget {
  const AsyncFilleddButton.icon({
    super.key,
    required Icon this.icon,
    required Widget label,
    required this.onPressed,
    this.style,
  }) : child = label;

  const AsyncFilleddButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.style,
  }) : icon = null;

  final Widget child;
  final Widget? icon;
  final FutureOr<void>? Function()? onPressed;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var animCtrler =
        useAnimationController(duration: const Duration(seconds: 1), lowerBound: 0.5, upperBound: 1, initialValue: 1);
    var actionRunning = useState(false);

    if (actionRunning.value) {
      animCtrler.repeat(reverse: true);
    } else {
      animCtrler.value = 1;
    }

    Widget animatedWidget = ScaleTransition(
      scale: CurvedAnimation(parent: animCtrler, curve: Curves.elasticInOut),
      child: icon ?? child,
    );

    var onPressedWrapped =
        onPressed != null && !actionRunning.value ? () => _onPressedWrapper(context, actionRunning, onPressed) : null;

    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressedWrapped,
        icon: animatedWidget,
        label: child,
        style: style,
      );
    }

    return FilledButton(
      onPressed: onPressedWrapped,
      style: style,
      child: animatedWidget,
    );
  }
}

_onPressedWrapper(
    BuildContext context, ValueNotifier<bool> valueNotifier, FutureOr<void>? Function()? onPressed) async {
  FutureOr<void>? ftr = onPressed!();
  if (ftr == null) return;
  valueNotifier.value = true;
  try {
    await ftr;
  } catch (e) {
    // Just catch the error since the button just reacts to the onPressed function
  }
  if (context.mounted) valueNotifier.value = false;
}
