import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AsyncElevatedButton extends HookConsumerWidget {
  const AsyncElevatedButton({
    Key? key,
    required this.child,
    required this.onPressed,
    this.style,
    this.margin,
  })  : label = null,
        super(key: key);

  const AsyncElevatedButton.icon({Key? key,
    required Icon icon,
    required Widget this.label,
    required this.onPressed,
    this.margin,
    this.style})
      : child = icon,
        super(key: key);

  factory AsyncElevatedButton.squareIcon({
    Key? key,
    required Icon icon,
    required FutureOr<void>? Function()? onPressed,
    EdgeInsetsGeometry? margin,
  }) {
    return AsyncElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(minimumSize: const Size.square(40)),
      margin: margin,
      child: icon,
    );
  }

  final Icon child;
  final Widget? label;
  final FutureOr<void>? Function()? onPressed;
  final ButtonStyle? style;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var animCtrler = useAnimationController(
        duration: const Duration(seconds: 1),
        lowerBound: 0.5,
        upperBound: 1,
        initialValue: 1);
    var actionRunning = useState(false);

    if (actionRunning.value) {
      animCtrler.repeat(reverse: true);
    } else {
      animCtrler.value = 1;
    }

    Widget ico = ScaleTransition(
      scale: CurvedAnimation(parent: animCtrler, curve: Curves.elasticInOut),
      child: child,
    );

    var onPressedWrapped = onPressed != null && !actionRunning.value
        ? () => _onPressedWrapper(context, actionRunning)
        : null;
    var btn = (label == null)
        ? ElevatedButton(
            onPressed: onPressedWrapped,
            style: style,
            child: ico,
          )
        : ElevatedButton.icon(
            style: style,
            onPressed: onPressedWrapped,
            icon: ico,
            label: label!,
          );
    if (margin == null) {
      return btn;
    }

    return Container(
      margin: margin,
      child: btn,
    );
  }

  _onPressedWrapper(BuildContext context,
      ValueNotifier<bool> valueNotifier) async {
    FutureOr<void>? ftr = onPressed!();
    if (ftr == null) return;
    valueNotifier.value = true;
    await ftr;
    if (context.mounted) valueNotifier.value = false;
  }
}
