/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class PrintStateNotificationSetting extends StatelessWidget {
  const PrintStateNotificationSetting({super.key, required this.activeStates, this.onChanged});

  final Set<PrintState> activeStates;
  final Function(PrintState, bool)? onChanged;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'pages.setting.notification.state_label'.tr(),
          labelStyle: themeData.textTheme.labelLarge,
          helperText: 'pages.setting.notification.state_helper'.tr(),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 8,
          children: PrintState.values.map((e) {
            var selected = activeStates.contains(e);
            return FilterChip(
              avatar: AnimatedCrossFade(
                firstChild: Icon(Icons.circle_notifications, color: themeData.colorScheme.primary),
                secondChild: Icon(Icons.circle_outlined, color: themeData.disabledColor),
                crossFadeState: selected ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                duration: kThemeAnimationDuration,
                firstCurve: Curves.easeInOutCirc,
                secondCurve: Curves.easeInOutCirc,
              ),
              showCheckmark: false,
              selected: selected,
              label: Text(e.displayName),
              onSelected: (onChanged == null ? null : (b) => onChanged!(e, b)),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}
