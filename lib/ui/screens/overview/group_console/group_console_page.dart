/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/console/gcode_store_entry.dart';
import 'package:common/data/enums/console_entry_type_enum.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/settings_bottom_sheet.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';

import 'group_console_controller.dart';

const _kMachineColors = [
  Colors.blue,
  Colors.deepOrange,
  Colors.green,
  Colors.purple,
  Colors.teal,
  Colors.amber,
  Colors.pink,
  Colors.indigo,
];

class GroupConsolePage extends HookConsumerWidget {
  const GroupConsolePage({super.key, required this.group});

  final PrinterGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commandController = useTextEditingController();
    final allEntries = ref.watch(groupConsoleEntriesProvider(group.machineUUIDs));
    final filterTemperature = ref.watch(boolSettingProvider(groupConsoleFilterTemperatureKey, true));
    final entries = filterTemperature
        ? allEntries.where((e) => e.entry.type != ConsoleEntryType.temperatureResponse).toList()
        : allEntries;

    final allMachines = ref.watch(allMachinesProvider).value ?? const <Machine>[];
    final indicatorMode = GroupConsoleIndicatorMode
        .values[ref.watch(intSettingProvider(AppSettingKeys.groupConsoleIndicatorMode))];
    final machineLabels = {
      for (final m in allMachines) m.uuid: indicatorMode.labelFor(m),
    };
    final machineColors = {
      for (var i = 0; i < group.machineUUIDs.length; i++)
        group.machineUUIDs[i]: _kMachineColors[i % _kMachineColors.length],
    };

    final newestAtTop = ref.watch(boolSettingProvider(groupConsoleReverseKey, false));
    final showTimestamp = ref.watch(boolSettingProvider(groupConsoleShowTimestampKey, true));
    final dateFormatService = ref.read(dateFormatServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(group.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: entries.isEmpty
                  ? Center(child: const Text('pages.overview.group_console.empty').tr())
                  : ListView.builder(
                      reverse: !newestAtTop,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final tagged = entries[entries.length - 1 - i];

                        DateFormat dateFormat = dateFormatService.Hms();
                        if (tagged.entry.timestamp.isNotToday()) {
                          dateFormat.addPattern('MMMd', ', ');
                        }

                        return _EntryTile(
                          machineName: machineLabels[tagged.machineUUID] ?? tagged.machineUUID,
                          color: machineColors[tagged.machineUUID] ?? Colors.grey,
                          entry: tagged.entry,
                          timestamp: showTimestamp ? dateFormat.format(tagged.entry.timestamp) : null,
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: _BroadcastInput(group: group, controller: commandController),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.machineName, required this.color, required this.entry, this.timestamp});

  final String machineName;
  final Color color;
  final GCodeStoreEntry entry;
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final isCommand = entry.type == ConsoleEntryType.command || entry.type == ConsoleEntryType.batchCommand;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2, right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(
              machineName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: themeData.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.message,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: isCommand ? themeData.colorScheme.primary : themeData.colorScheme.onSurface,
                    fontWeight: isCommand ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (timestamp != null) Text(timestamp!, style: themeData.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastInput extends ConsumerWidget {
  const _BroadcastInput({required this.group, required this.controller});

  final PrinterGroup group;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void submit() {
      final command = controller.text;
      if (command.isEmpty) return;
      for (final uuid in group.machineUUIDs) {
        ref.read(printerServiceProvider(uuid)).gCode(command).ignore();
      }
      controller.clear();
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasInput = controller.text.isNotEmpty;
        return TextField(
          controller: controller,
          onSubmitted: (_) => submit(),
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: tr('pages.overview.group_console.command_hint'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: hasInput
                ? IconButton(icon: const Icon(Icons.send), onPressed: submit)
                : IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => ref.read(bottomSheetServiceProvider).show(
                          BottomSheetConfig(
                            type: SheetType.changeSettings,
                            data: SettingsBottomSheetArgs(
                              title: tr('pages.overview.group_console.settings.title'),
                              settings: [
                                SwitchSettingItem(
                                  settingKey: groupConsoleReverseKey,
                                  title: tr('bottom_sheets.console_settings.reverse.title'),
                                  subtitle: tr('bottom_sheets.console_settings.reverse.subtitle'),
                                ),
                                SwitchSettingItem(
                                  settingKey: groupConsoleFilterTemperatureKey,
                                  title: tr('bottom_sheets.console_settings.filter_temp_responses.title'),
                                  subtitle: tr('bottom_sheets.console_settings.filter_temp_responses.subtitle'),
                                  defaultValue: true,
                                ),
                                SwitchSettingItem(
                                  settingKey: groupConsoleShowTimestampKey,
                                  title: tr('bottom_sheets.console_settings.show_timestamps.title'),
                                  subtitle: tr('bottom_sheets.console_settings.show_timestamps.subtitle'),
                                  defaultValue: true,
                                ),
                                const DividerSettingItem(),
                                ChoiceSettingItem<GroupConsoleIndicatorMode>(
                                  settingKey: AppSettingKeys.groupConsoleIndicatorMode,
                                  title: tr('pages.overview.group_console.settings.indicator_title'),
                                  subtitle: tr('pages.overview.group_console.settings.indicator_subtitle'),
                                  options: GroupConsoleIndicatorMode.values,
                                  labelBuilder: (mode) => tr(mode.labelTranslationKey),
                                  optionSubtitleBuilder: (mode) => tr(mode.descriptionTranslationKey),
                                  defaultValue: GroupConsoleIndicatorMode.machineName,
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
          ),
        );
      },
    );
  }
}
