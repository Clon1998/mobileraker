/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    this.child,
    this.title,
    this.titleLeading,
    this.body,
  })  : assert(child != null || (title != null && body != null), 'Either provide the child or the title'),
        assert(child == null || (title == null && body == null), 'Only define the child or the title and body!');

  factory ErrorCard.fromError(Object error, StackTrace stackTrace) {
    return ErrorCard(
      title: const Text('Error'),
      body: Text('An error occured: $error\n$stackTrace'),
    );
  }

  final Widget? child;
  final Widget? title;
  final Widget? titleLeading;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    var scheme = Theme.of(context).colorScheme;
    return Center(
      child: Card(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(40.0),
        ),
        color: scheme.errorContainer,
        child: child ?? _fallbackChild(scheme),
      ),
    );
  }

  Widget _fallbackChild(ColorScheme scheme) {
    return DefaultTextStyle(
      style: TextStyle(color: scheme.onErrorContainer),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            textColor: scheme.onErrorContainer,
            iconColor: scheme.onErrorContainer,
            leading: titleLeading,
            title: title,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: body,
          ),
        ],
      ),
    );
  }
}
