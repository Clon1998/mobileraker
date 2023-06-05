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

  const AsyncElevatedButton.icon(
      {Key? key,
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
    required VoidCallback? onPressed,
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
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final EdgeInsetsGeometry? margin;

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

    var btn = (label == null)
        ? ElevatedButton(
            onPressed: onPressed,
            style: style,
            child: ico,
          )
        : ElevatedButton.icon(
            style: style,
            onPressed: onPressed,
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
}
