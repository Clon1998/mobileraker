/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/device_fcm_settings_service.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/notification_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/jrpc_client_provider.dart';
import '../ui/locale_spy.dart';

part 'device_fcm_settings_sync_service.g.dart';

@riverpod
DeviceFcmSettingsSyncService deviceFcmSettingsSyncService(Ref ref) {
  ref.keepAlive();
  return DeviceFcmSettingsSyncService(ref);
}

/// A service responsible for synchronizing device FCM (Firebase Cloud Messaging) settings with connected machines.
///
/// This service handles:
/// - Retrieval and management of device notification preferences
/// - Synchronization of FCM tokens and notification settings to machines
/// - Cleanup of orphaned FCM entries to prevent routing issues
/// - Construction of device-specific FCM settings objects
///
/// The service ensures that any changes to local notification preferences, device tokens,
/// or other relevant settings are properly propagated to all connected machines, allowing
/// them to send appropriately configured push notifications back to this device.
///
class DeviceFcmSettingsSyncService {
  DeviceFcmSettingsSyncService(this.ref) : _deviceFcmService = ref.watch(deviceFcmSettingsServiceProvider) {
    ref.onDispose(dispose);
  }

  final Ref ref;

  final DeviceFcmSettingsService _deviceFcmService;

  final List<StreamSubscription> _subscriptions = [];

  final Map<String, ProviderSubscription> _machineSubscriptions = {};

  void initialize() {
    // TODO: Decide if we always want to do a BIG sync for settings or handle them individually per field

    _setupFcmTokenListener();
    _setupLanguageListener();
    _setupSettingListeners();
    _setupConnectionListeners();
    talker.info('[SettingsSyncService] initialized');
  }

  void _setupFcmTokenListener() {
    ref.listen(fcmTokenProvider, (prev, next) {
      if (prev == next || next.valueOrNull == null) return;

      talker.info('[SettingsSyncService] FCM token changed, marking for sync $prev -> $next');
      _syncToConnectedMachines();
    });
  }

  void _setupLanguageListener() {
    ref.listen(activeLocaleProvider, (prev, next) {
      if (prev == next) return; // Skip if unchanged

      talker.info('[SettingsSyncService] Language changed, marking for sync $prev -> $next');
      _syncToConnectedMachines();
    });
  }

  /// Sets up listeners for all settings that need to be synced to machines
  void _setupSettingListeners() {
    /// General settings

    // Time format setting
    ref.listen(boolSettingProvider(AppSettingKeys.timeFormat), (prev, next) {
      if (prev == next) return; // Skip if unchanged
      talker.info('[SettingsSyncService] Time format changed to $next, marking for sync, $prev -> $next');
      _syncToConnectedMachines();
    });

    /// Notification settings

    // Progress notification mode setting
    ref.listen(intSettingProvider(AppSettingKeys.progressNotificationMode, -1), (prev, next) {
      if (prev == next) return; // Skip if unchanged

      talker.info('[SettingsSyncService] Progress notification mode changed, marking for sync $prev -> $next');
      _syncToConnectedMachines();
    });

    // Progressbar notifications setting
    ref.listen(boolSettingProvider(AppSettingKeys.useProgressbarNotifications, true), (prev, next) {
      if (prev == next) return; // Skip if unchanged

      talker.info('[SettingsSyncService] Progressbar notifications setting changed, marking for sync $prev -> $next');
      _syncToConnectedMachines();
    });

    // States triggering notification setting
    ref.listen(listSettingProvider(AppSettingKeys.statesTriggeringNotification), (prev, next) {
      if (DeepCollectionEquality.unordered().equals(prev, next)) return; // Skip if unchanged

      talker.info('[SettingsSyncService] States triggering notification changed, marking for sync $prev -> $next');
      _syncToConnectedMachines();
    });

    // ETA sources setting
    ref.listen(listSettingProvider(AppSettingKeys.etaSources), (prev, next) {
      if (DeepCollectionEquality.unordered().equals(prev, next)) return; // Skip if unchanged

      talker.info('[SettingsSyncService] ETA sources changed, marking for sync $prev -> $next');
      _syncToConnectedMachines();
    });
  }

  // You can add more setting listeners here as needed
  /// Sets up listeners for machine connections to sync pending settings
  void _setupConnectionListeners() {
    talker.info('[SettingsSyncService] Setting up all machines listener for connection monitoring');
    // Monitor machines list and machine connection states
    ref.listen(allMachinesProvider, (previous, next) {
      next.whenData((machines) {
        talker.info('[SettingsSyncService] Machines list updated, checking for changes');
        final allUuids = machines.map((m) => m.uuid).toList();
        // Identify new machines
        final newMachines = machines.where((m) => !_machineSubscriptions.containsKey(m.uuid)).toList();

        // Identify removed machines
        final removedMachines = _machineSubscriptions.keys.where((uuid) => !allUuids.contains(uuid)).toList();

        // Remove subscriptions for removed machines
        for (final uuid in removedMachines) {
          talker.info('[SettingsSyncService] Machine $uuid removed, closing subscription for connection monitoring');
          _machineSubscriptions.remove(uuid)?.close();
        }

        // Add subscriptions for new machines
        for (final machine in newMachines) {
          talker.info(
              '[SettingsSyncService] Machine ${machine.uuid} discovered, opening subscription for connection monitoring');
          _monitorMachineConnection(machine);
        }
        talker.info(
            '[SettingsSyncService] Machines list updated. Adjusted connection monitoring, new: ${newMachines.length}, removed: ${removedMachines.length} machines');
      });
    }, fireImmediately: true);
  }

  /// Monitors connection state changes for a specific machine
  void _monitorMachineConnection(Machine machine) {
    talker.info('[SettingsSyncService] Monitoring connection state for machine ${machine.logTagExtended}');
    // Close existing subscription if it exists, just in case
    _machineSubscriptions[machine.uuid]?.close();
    final sub = ref.listen(jrpcClientStateProvider(machine.uuid), (prev, next) {
      // Only care about transitions to connected state
      if (prev?.valueOrNull != ClientState.connected && next.valueOrNull == ClientState.connected) {
        talker.info('[SettingsSyncService] ${machine.logTagExtended} Machine connected, syncing settings');
        _syncDataToMachine(machine, true);
      }
    }, fireImmediately: true);

    _machineSubscriptions[machine.uuid] = sub;
  }

  /// Syncs current settings to all currently connected machines
  Future<void> _syncToConnectedMachines() async {
    talker.info('[SettingsSyncService] Syncing settings to all connected machines');

    final machines = await ref.read(allMachinesProvider.future);

    for (final machine in machines) {
      try {
        final connectionState = await ref.read(jrpcClientStateProvider(machine.uuid).future);

        if (connectionState == ClientState.connected) {
          talker.info('[SettingsSyncService] ${machine.logTagExtended} Machine connected, syncing settings');
          await _syncDataToMachine(machine);
        } else {
          talker.info('[SettingsSyncService] ${machine.logTagExtended} Machine not connected, will sync later');
        }
      } catch (e) {
        talker.warning('[SettingsSyncService] ${machine.logTagExtended} Error checking connection state', e);
      }
    }
  }

  /// Syncs all settings to a specific machine
  Future<void> _syncDataToMachine(Machine machine, [bool clearOrphan = false]) async {
    _deviceFcmService.syncDeviceFcmToMachine(machine, clearOrphan);
  }

  void dispose() {
    talker.info('SettingsSyncService disposed');
  }
}
