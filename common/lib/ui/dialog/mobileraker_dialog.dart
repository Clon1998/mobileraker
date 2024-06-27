/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class MobilerakerDialog extends StatelessWidget {
  const MobilerakerDialog({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(15),
    EdgeInsets? paddingFooter,
    this.clipBehavior = Clip.none,
    this.maxWidth = 500,
    this.footer,
    this.actionText,
    this.onAction,
    this.actionStyle,
    this.dismissText,
    this.onDismiss,
    this.dismissStyle,
  })  : paddingFooter = paddingFooter ?? padding,
        assert(maxWidth >= 0, "The max width must be greater than 0");

  final Widget child;
  final EdgeInsets padding;
  final Clip clipBehavior;
  final double maxWidth;

  final Widget? footer;
  final EdgeInsets paddingFooter;

  final String? actionText;
  final VoidCallback? onAction;
  final ButtonStyle? actionStyle;

  final String? dismissText;
  final VoidCallback? onDismiss;
  final ButtonStyle? dismissStyle;

  @override
  Widget build(BuildContext context) {
    // We want to have control over the distance between the footer and the content so we need to adjust the padding
    EdgeInsets actualPaddingFooter =
        EdgeInsets.fromLTRB(paddingFooter.left, 0, paddingFooter.right, paddingFooter.bottom);
    EdgeInsets actualPadding = EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0);

    Widget? footer = this.footer;
    if (actionText != null || dismissText != null) {
      footer = OverflowBar(
        spacing: 4,
        alignment: MainAxisAlignment.end,
        children: [
          if (dismissText != null)
            TextButton(
              onPressed: onDismiss,
              style: dismissStyle,
              child: Text(dismissText!),
            ),
          if (actionText != null)
            FilledButton.tonal(
              onPressed: onAction,
              style: actionStyle,
              child: Text(actionText!),
            ),
        ],
      );
    }

    return Dialog(
      clipBehavior: clipBehavior,
      child: ConstrainedBox(
        //TODO: Determine if this is the right width
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Padding(
                padding: footer == null ? padding : actualPadding,
                child: child,
              ),
            ),
            if (footer != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: actualPaddingFooter,
                child: footer,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
