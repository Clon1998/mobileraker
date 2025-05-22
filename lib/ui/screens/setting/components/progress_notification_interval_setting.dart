/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/progress_notification_mode.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ProgressNotificationIntervalSetting extends StatelessWidget {
  const ProgressNotificationIntervalSetting({
    super.key,
    required this.value,
    this.onChanged,
  });

  final ProgressNotificationMode? value;
  final ValueChanged<ProgressNotificationMode?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: 'pages.setting.notification.progress_label'.tr(),
        helperText: 'pages.setting.notification.progress_helper'.tr(),
      ),
      child: DropdownButton(
        isDense: true,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        value: value,
        items: ProgressNotificationMode.values
            .map((mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(mode.progressNotificationModeStr()),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
