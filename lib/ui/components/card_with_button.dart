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
      child: Card(
        elevation: 2,
        color: backgroundColor ?? Theme.of(context).primaryColorLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                child: child,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(radius),
                      bottomRight: Radius.circular(radius))),
              child: Container(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(primary: Colors.white),
                    child: buttonChild,
                    onPressed: onTap,
                  )),
            )
          ],
        ),
      ),
    );
  }
}
