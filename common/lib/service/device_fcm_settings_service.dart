/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/fcm/notification_settings.dart';
import 'package:common/data/repository/fcm/device_fcm_settings_repository_impl.dart';
import 'package:common/service/machine_fcm_settings_service.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/dto/machine/print_state_enum.dart';
import '../data/enums/eta_data_source.dart';
import '../data/model/hive/progress_notification_mode.dart';
import '../data/model/moonraker_db/fcm/device_fcm_settings.dart';
import '../ui/locale_spy.dart';
import 'misc_providers.dart';
import 'notification_service.dart';

part 'device_fcm_settings_service.g.dart';

@riverpod
DeviceFcmSettingsService deviceFcmSettingsService(Ref ref) {
  ref.keepAlive();
  return DeviceFcmSettingsService(ref);
}

/// Service responsible for handling logic related to device FCM (settings)
class DeviceFcmSettingsService {
  DeviceFcmSettingsService(this.ref)
      : _settingService = ref.watch(settingServiceProvider),
        _machineService = ref.watch(machineServiceProvider);

  final Ref ref;

  final SettingService _settingService;

  final MachineService _machineService;

  /// Get the device (Phone) notification settings
  NotificationSettings deviceNotificationSettings() {
    final progressModeInt = _settingService.readInt(AppSettingKeys.progressNotificationMode, -1);
    final progressMode =
        (progressModeInt < 0) ? ProgressNotificationMode.TWENTY_FIVE : ProgressNotificationMode.values[progressModeInt];

    final states = _settingService
        .readList<PrintState>(AppSettingKeys.statesTriggeringNotification, elementDecoder: PrintState.fromJson)
        .toSet();
    final etaSources = _settingService
        .readList<ETADataSource>(AppSettingKeys.etaSources, elementDecoder: ETADataSource.fromJson)
        .toSet();

    final useProgressbar = _settingService.readBool(AppSettingKeys.useProgressbarNotifications);

    var now = DateTime.now();
    return NotificationSettings(
      created: now,
      lastModified: now,
      progress: progressMode.value,
      states: states,
      etaSources: etaSources,
      androidProgressbar: useProgressbar,
    );
  }

  Future<void> syncDeviceFcmToMachine(Machine machine, [bool clearOrphan = false]) async {
    final keepAliveLink = ref.keepAliveExternally(machineFcmSettingsServiceProvider(machine.uuid));
    try {
      talker.info('[DeviceFcmService] Syncing device FCM to machine ${machine.logName})');
      final machineFcmService = keepAliveLink.read();

      if (clearOrphan) {
        // Clear orphaned entries
        final curToken = await ref.read(fcmTokenProvider.future);
        await machineFcmService.clearOrphanDeviceFcm(curToken);
      }

      // Get the latest local settings
      final localDeviceFcm = await _latest(machine.name);

      final latest = await machineFcmService.applyLocalDeviceDeltaIfNeeded(localDeviceFcm);
      talker.info('[DeviceFcmService] Latest DeviceFcmSettings: $latest');
    } catch (e, s) {
      talker.warning('[DeviceFcmService] Error syncing device FCM to machine.', e, s);
    } finally {
      keepAliveLink.close();
    }
  }

  /// Removes all stored fcm tokens+configs from the machines moonraker database
  Future<void> clearAllDeviceFcm(Machine machine) async {
    try {
      await ref.read(deviceFcmSettingsRepositoryProvider(machine.uuid)).deleteAll();
    } catch (e) {
      talker.warning('[DeviceFcmService] Error clearing all device FCM settings', e);
    }
  }

  Future<String?> _fetchAppVersion() async {
    try {
      var packageInfo = await ref.watch(versionInfoProvider.future);
      return '${packageInfo.version}-${Platform.operatingSystem}';
    } catch (e) {
      talker.warning('Was unable to fetch version info', e);
    }
    return null;
  }

  /// Fetches the latest device FCM settings present on the app
  Future<DeviceFcmSettings> _latest(String machineName) async {
    final deviceFcmToken = await ref.read(fcmTokenProvider.future);
    final version = await _fetchAppVersion();
    final notificationSettings = deviceNotificationSettings();
    final language = ref.read(activeLocaleProvider).toString();
    final timeFormat = _settingService.readBool(AppSettingKeys.timeFormat) ? '12h' : '24h';

    final now = DateTime.now();

    return DeviceFcmSettings(
      created: now,
      lastModified: now,
      fcmToken: deviceFcmToken,
      machineName: machineName,
      language: language,
      timeFormat: timeFormat,
      version: version,
      settings: notificationSettings,
    );
  }
}
