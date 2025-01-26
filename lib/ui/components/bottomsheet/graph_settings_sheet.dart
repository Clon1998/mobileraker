/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/temperature_store_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/color_scheme_extension.dart';
import 'package:common/util/misc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class GraphSettingsSheet extends ConsumerWidget {
  const GraphSettingsSheet({super.key, required this.machineUUID});

  final String machineUUID;

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
      body: _OptionsList(machineUUID: machineUUID),
    );
  }
}

class _OptionsList extends ConsumerWidget {
  const _OptionsList({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.read(temperatureStoresProvider(machineUUID)).valueOrNull ?? {};

    if (stores.isEmpty) {
      return const ListTile(
        title: Text('No temperature stores found'),
      );
    }

    var entries = stores.entries.toList();

    return ListView.builder(
      itemCount: stores.length,
      padding: EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final store = entries.elementAt(index);
        final themeData = Theme.of(context);
        final color = themeData.colorScheme.colorsForEntry(index);
        return HookBuilder(
          builder: (context) {
            final tempSettingKey =
                CompositeKey.keyWithStrings(UtilityKeys.graphSettings, [store.key.$1.name, store.key.$2]);

            final targetSettingKey = CompositeKey.keyWithString(tempSettingKey, 'target');

            return Row(
              children: [
                Icon(Icons.circle, size: 10, color: color.$1),
                Gap(8),
                Text(
                  beautifyName(store.key.$2),
                  style: themeData.textTheme.bodyLarge,
                  maxLines: 1,
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      Consumer(builder: (context, ref, _) {
                        final settingService = ref.watch(settingServiceProvider);
                        final active = ref.watch(boolSettingProvider(tempSettingKey, true));

                        return FilterChip(
                          avatar: AnimatedCrossFade(
                            firstChild: Icon(FlutterIcons.chart_line_mco, color: color.$1),
                            // firstChild: Icon(FlutterIcons.line_graph_ent, color: color.$1),
                            secondChild: Icon(Icons.circle_outlined, color: themeData.disabledColor),
                            crossFadeState: active ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            duration: kThemeAnimationDuration,
                            firstCurve: Curves.easeInOutCirc,
                            secondCurve: Curves.easeInOutCirc,
                          ),
                          showCheckmark: false,
                          selected: active,
                          elevation: 2,
                          label: Text('Temp'),
                          selectedColor: color.$2,
                          side: BorderSide(color: color.$1),
                          // backgroundColor: color.$2,
                          onSelected: (bool s) => settingService.writeBool(tempSettingKey, s),
                        );
                      }),
                      Consumer(builder: (context, ref, _) {
                        final settingService = ref.watch(settingServiceProvider);
                        final active = ref.watch(boolSettingProvider(targetSettingKey, true));

                        return FilterChip(
                          avatar: AnimatedCrossFade(
                            firstChild: Icon(FlutterIcons.chart_areaspline_variant_mco, color: color.$1),
                            secondChild: Icon(Icons.circle_outlined, color: themeData.disabledColor),
                            crossFadeState: active ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            duration: kThemeAnimationDuration,
                            firstCurve: Curves.easeInOutCirc,
                            secondCurve: Curves.easeInOutCirc,
                          ),
                          showCheckmark: false,
                          selected: active,
                          elevation: 2,
                          label: Text('Target'),
                          selectedColor: color.$2,
                          side: BorderSide(color: color.$2),
                          // backgroundColor: color.$2,
                          onSelected: (bool s) => settingService.writeBool(targetSettingKey, s),
                        );
                      }),

                      // Chip(label: Text('PWM'), backgroundColor: Colors.lime),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
