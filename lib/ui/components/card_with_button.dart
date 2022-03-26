import 'package:flutter/material.dart';

class CardWithButton extends StatelessWidget {
  static const double radius = 20;

  const CardWithButton({
    Key? key,
    required this.width,
    this.backgroundColor,
    required this.child,
    required this.buttonChild,
    required this.onTap,
  }) : super(key: key);

  final double width;
  final Color? backgroundColor;
  final Widget child;
  final Widget buttonChild;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: CardTheme.of(context).margin ?? const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
                color: backgroundColor ?? Theme.of(context).primaryColorLight,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(radius))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              child: child,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
                primary: Colors.white,
                backgroundColor: Theme.of(context).primaryColor,
                minimumSize: const Size.fromHeight(48),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
                )),
            child: buttonChild,
            onPressed: onTap,
          )
        ],
      ),
    );
  }
}
