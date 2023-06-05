import 'package:flutter/material.dart';

class SquareElevatedIconButton extends StatelessWidget {
  const SquareElevatedIconButton(
      {Key? key, this.onPressed, this.margin, this.child})
      : super(key: key);

  final VoidCallback? onPressed;

  final EdgeInsetsGeometry? margin;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: margin,
        child: ElevatedButton(
            key: key,
            style: ElevatedButton.styleFrom(minimumSize: const Size.square(40)),
            onPressed: onPressed,
            child: child));
  }
}
