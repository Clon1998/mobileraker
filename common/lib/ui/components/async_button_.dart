/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'mobileraker_icon_button.dart';

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
  const AsyncIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.onLongPressed,
    this.style,
    this.iconSize,
    this.tooltip,
    this.color,
  });

  final Icon icon;
  final FutureOr<void>? Function()? onPressed;
  final FutureOr<void>? Function()? onLongPressed;
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

    var onLongPressedWrapper = onLongPressed != null && !actionRunning.value
        ? () => _onPressedWrapper(context, actionRunning, onLongPressed)
        : null;

    return MobilerakerIconButton(
      onPressed: onPressedWrapped,
      onLongPressed: onLongPressedWrapper,
      icon: ico,
      color: color,
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

class AsyncFilledButton extends HookConsumerWidget {
  const AsyncFilledButton.icon({
    super.key,
    required Icon this.icon,
    required Widget label,
    required this.onPressed,
    this.style,
  }) : child = label;

  const AsyncFilledButton({
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

class AsyncSwitch extends HookConsumerWidget {
  const AsyncSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final FutureOr<void>? Function(bool)? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switchValue = useState(value);
    // use sideffect to trigger switchValue update if value changes
    useEffect(() {
      switchValue.value = value;
      return null;
    }, [value]);

    final animCtrler =
        useAnimationController(duration: const Duration(seconds: 1), lowerBound: 0.5, upperBound: 1, initialValue: 1);
    final actionRunning = useState(false);

    if (actionRunning.value) {
      animCtrler.repeat(reverse: true);
    } else {
      animCtrler.value = 1;
    }
    logger.wtf('AsyncSwitch: ${switchValue.value}, ${value}');

    return ScaleTransition(
      scale: CurvedAnimation(parent: animCtrler, curve: Curves.elasticInOut),
      child: Switch(
        value: switchValue.value,
        onChanged: (b) {
          FutureOr<void>? ftr = onChanged!(b);
          if (ftr == null) return;
          switchValue.value = b;
          actionRunning.value = true;

          Future.value(ftr).whenComplete(() {
            if (context.mounted) actionRunning.value = false;
          });
        }.unless(onChanged == null || actionRunning.value),
      ),
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
