/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/object_extension.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class WarningCard extends ConsumerWidget {
  const WarningCard({
    super.key,
    this.show = true,
    this.onTap,
    this.title,
    this.subtitle,
    this.leadingIcon,
    this.actionLabel,
    this.margin = const EdgeInsets.only(top: 16),
  });

  final bool show;
  final VoidCallback? onTap;
  final Widget? title;
  final Widget? subtitle;
  final Widget? leadingIcon;

  /// Label of a button below the text that does the same as tapping the card ([onTap]), so the text does not have to
  /// explain that the card can be tapped. Only shown while there is an [onTap].
  final Widget? actionLabel;

  final EdgeInsets margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        duration: kThemeAnimationDuration,
        child: show
            ? Padding(
                padding: margin,
                child: Material(
                  color: themeData.colorScheme.errorContainer,
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
                  child: InkWell(
                    onTap: onTap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          tileColor: themeData.colorScheme.errorContainer,
                          textColor: themeData.colorScheme.onErrorContainer,
                          iconColor: themeData.colorScheme.onErrorContainer,
                          leading: leadingIcon?.let(
                            (it) => IconTheme(
                              data: themeData.iconTheme.copyWith(
                                color: themeData.colorScheme.onErrorContainer,
                                size: 40,
                              ),
                              child: it,
                            ),
                          ),
                          title: title,
                          subtitle: subtitle,
                        ),
                        if (actionLabel != null && onTap != null)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(end: 12, bottom: 10),
                              child: OutlinedButton(
                                onPressed: onTap,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: themeData.colorScheme.onErrorContainer,
                                  side: BorderSide(color: themeData.colorScheme.onErrorContainer),
                                ),
                                child: actionLabel!,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
