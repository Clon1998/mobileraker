/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/filament_sensors/filament_sensor.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class IgnoreFilamentSensorsNotificationSetting extends StatelessWidget {
  const IgnoreFilamentSensorsNotificationSetting({
    super.key,
    required this.filamentSensors,
    required this.excludedSensors,
    this.onChanged,
  });

  final List<FilamentSensor> filamentSensors;
  final Set<String> excludedSensors;
  final Function(FilamentSensor, bool)? onChanged;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'pages.setting.notification.ignore_filament_sensors_label'.tr(),
          labelStyle: themeData.textTheme.labelLarge,
          helperText: 'pages.setting.notification.ignore_filament_sensors_helper'.tr(),
          helperMaxLines: 99,
        ),
        child: filamentSensors.isNotEmpty
            ? Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8,
                children: [
                  ...filamentSensors.map((e) {
                    final selected = !excludedSensors.contains('${e.kind.name}#${e.name}');
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
                      label: Text(beautifyName(e.name)),
                      onSelected: (onChanged == null ? null : (b) => onChanged!(e, b)),
                    );
                  }),
                ],
              )
            : Text('pages.setting.notification.ignore_filament_sensors_empty',
                    style: themeData.textTheme.bodyLarge?.copyWith(color: themeData.disabledColor))
                .tr(),
      ),
    );
  }
}
