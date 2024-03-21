/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';

class CardWithSwitch extends HookWidget {
  static const double radius = 15;

  const CardWithSwitch({
    super.key,
    this.backgroundColor,
    this.onChanged,
    required this.value,
    required this.builder,
  });

  final Color? backgroundColor;
  final ValueChanged<bool>? onChanged;
  final bool value;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    var bgColor = backgroundColor ?? themeData.colorScheme.surfaceVariant;
    var onBackgroundColor = (ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark
        ? Colors.white.blendAlpha(themeData.colorScheme.primary.brighten(20), 0)
        : Colors.black.blendAlpha(themeData.colorScheme.primary.brighten(20), 0));

    ValueNotifier<bool?> lastState = useState(null);
    ValueNotifier<bool> loading = useState(false);
    if (loading.value && lastState.value != value) {
      loading.value = false;
    }

    Widget iconButton = IconButton(
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        maximumSize: const Size.fromHeight(48),
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
        ),
        foregroundColor: themeData.colorScheme.onPrimary,
        backgroundColor: themeData.colorScheme.primary,
        disabledForegroundColor: themeData.colorScheme.onPrimary.withOpacity(0.38),
      ),
      disabledColor: themeData.colorScheme.onPrimary.withOpacity(0.38),
      color: themeData.colorScheme.onPrimary,
      onPressed: onChanged != null && !loading.value
          ? () {
              lastState.value = value;
              loading.value = true;
              onChanged!(!value);
            }
          : null,
      icon: AnimatedSwitcher(
        duration: kThemeAnimationDuration,
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, anim) => RotationTransition(
          turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1).animate(anim),
            child: child,
          ),
        ),
        child: _animIcon(loading.value, value),
      ),
    );

    if (!themeData.useMaterial3) {
      iconButton = Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: themeData.colorScheme.primary,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(radius),
          ),
        ),
        child: iconButton,
      );
    }

    return Container(
      padding: CardTheme.of(context).margin ?? const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(radius)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              child: Theme(
                data: themeData.copyWith(
                  textTheme: themeData.textTheme.apply(
                    bodyColor: onBackgroundColor,
                    displayColor: onBackgroundColor,
                  ),
                  iconTheme: themeData.iconTheme.copyWith(color: onBackgroundColor),
                ),
                child: DefaultTextStyle(
                  style: TextStyle(color: onBackgroundColor),
                  child: Builder(builder: builder),
                ),
              ),
            ),
          ),
          iconButton,
        ],
      ),
    );
  }

  Widget _animIcon(bool isLoading, bool state) {
    if (isLoading) {
      return const Icon(Icons.pending_outlined);
    }

    return state
        ? const Icon(FlutterIcons.power_on_mco, key: ValueKey('on'))
        : const Icon(FlutterIcons.power_off_mco, key: ValueKey('off'));
  }
}
