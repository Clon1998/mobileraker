/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/settings_bottom_sheet.dart';

class ConsoleSettingsButton extends ConsumerWidget {
  const ConsoleSettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.settings),
      onPressed: () {
        ref
            .read(bottomSheetServiceProvider)
            .show(
          BottomSheetConfig(
            type: SheetType.changeSettings,
            data: SettingsBottomSheetArgs(
              title: tr('bottom_sheets.console_settings.title'),
              settings: [
                SwitchSettingItem(
                  settingKey: AppSettingKeys.reverseConsole,
                  title: tr('bottom_sheets.console_settings.reverse.title'),
                  subtitle: tr('bottom_sheets.console_settings.reverse.subtitle'),
                ),
                SwitchSettingItem(
                  settingKey: AppSettingKeys.filterTemperatureResponse,
                  title: tr('bottom_sheets.console_settings.filter_temp_responses.title'),
                  subtitle: tr('bottom_sheets.console_settings.filter_temp_responses.subtitle'),
                ),
                SwitchSettingItem(
                  settingKey: AppSettingKeys.consoleShowTimestamp,
                  title: tr('bottom_sheets.console_settings.show_timestamps.title'),
                  subtitle: tr('bottom_sheets.console_settings.show_timestamps.subtitle'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}