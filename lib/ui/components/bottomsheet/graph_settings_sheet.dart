/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class GraphSettingsSheet extends ConsumerWidget {
  const GraphSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        title: Text(
          'Graph Settings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );

    return SheetContentScaffold(
      appBar: title,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shrinkWrap: true,
        children: [
          // SwitchListTile(
          //   contentPadding: EdgeInsets.zero,
          //   visualDensity: VisualDensity.compact,
          //   value: ref.watch(boolSettingProvider(GCodeVisualizerSettingsKey.showCurrentLayer)),
          //   title: Text('Show Current Layer'),
          //   subtitle: Text('Show the current layer in the preview'),
          //   onChanged: (value) =>
          //       ref.read(settingServiceProvider).write(GCodeVisualizerSettingsKey.showCurrentLayer, value),
          // ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            value: true,
            title: const Text('Extruder 1').tr(),
            subtitle: const Text('Visible').tr(),
            onChanged: (value) => null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: const Text('Extruder 1').tr(),
            subtitle: Row(
              children: [
                Chip(label: Text('Temp'), backgroundColor: Colors.deepOrange),
                Chip(label: Text('Target'), backgroundColor: Colors.purpleAccent),
                Chip(label: Text('PWM'), backgroundColor: Colors.lime),
              ],
            ),
          ),

          const Divider(),
          const Gap(8),
          // SliderOrTextInput(
          //   value: ref.watch(doubleSettingProvider(GCodeVisualizerSettingsKey.extrusionWidthMultiplier)),
          //   prefixText: tr('components.gcode_preview_settings_sheet.extrusion_width_multiplier.prefix'),
          //   onChange: (v) =>
          //       ref.read(settingServiceProvider).write(GCodeVisualizerSettingsKey.extrusionWidthMultiplier, v),
          //   submitOnChange: true,
          // ),
        ],
      ),
    );
  }
}
