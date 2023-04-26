import 'package:flutter/material.dart';

class ErrorCard extends StatelessWidget {
  const ErrorCard({Key? key, required this.child}) : super(key: key);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(40.0),
          ),
          color: Theme.of(context).colorScheme.errorContainer,
          child: child),
    );
  }
}
