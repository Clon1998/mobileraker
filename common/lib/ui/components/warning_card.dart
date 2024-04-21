/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
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
    this.margin = const EdgeInsets.only(top: 16),
  });

  final bool show;
  final VoidCallback? onTap;
  final Widget? title;
  final Widget? subtitle;
  final Widget? leadingIcon;

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
                child: ListTile(
                  tileColor: themeData.colorScheme.errorContainer,
                  textColor: themeData.colorScheme.onErrorContainer,
                  iconColor: themeData.colorScheme.onErrorContainer,
                  onTap: onTap,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  leading: leadingIcon?.let((it) => IconTheme(
                        data: themeData.iconTheme.copyWith(
                          color: themeData.colorScheme.onErrorContainer,
                          size: 40,
                        ),
                        child: it,
                      )),
                  title: title,
                  subtitle: subtitle,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
