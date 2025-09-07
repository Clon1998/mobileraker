/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/repository/fcm/device_fcm_settings_repository_impl.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/dto/machine/print_state_enum.dart';
import '../data/model/moonraker_db/fcm/device_fcm_settings.dart';
import '../data/repository/fcm/device_fcm_settings_repository.dart';
import '../util/logger.dart';

part 'machine_fcm_settings_service.g.dart';

@riverpod
MachineFcmSettingsService machineFcmSettingsService(Ref ref, String machineUUID) {
  final repository = ref.watch(deviceFcmSettingsRepositoryProvider(machineUUID));
  final machineService = ref.watch(machineServiceProvider);

  return MachineFcmSettingsService(
    machineUUID: machineUUID,
    repository: repository,
    machineService: machineService,
  );
}

class MachineFcmSettingsService {
  const MachineFcmSettingsService({
    required this.machineUUID,
    required this.repository,
    required this.machineService,
  });

  final String machineUUID;

  final DeviceFcmSettingsRepository repository;

  final MachineService machineService;

  /// Applies changes from local device FCM settings to the remote settings if differences exist.
  ///
  /// This method compares the provided [localDeviceFcm] settings with the current
  /// settings stored for this machine. If differences are detected or no settings
  /// exist yet, it will:
  ///
  /// 1. For new machines (no existing settings): Create a complete new entry
  /// 2. For existing machines: Apply only the changed fields as a delta update
  /// 3. Respect inheritance settings by not overwriting machine-specific preferences
  ///    when inheritance is disabled
  ///
  /// The method ensures efficient updates by only writing to storage when actual
  /// changes are detected, minimizing network operations and database writes.
  ///
  /// @param localDeviceFcm The local device settings to compare and potentially apply
  /// @return The updated settings if changes were made, or the current settings if no changes
  ///         were needed. Returns null if no current settings exist and no update was performed.

  Future<DeviceFcmSettings?> applyLocalDeviceDeltaIfNeeded(DeviceFcmSettings localDeviceFcm) async {
    // Get the current settings for the machine
    final currentDeviceFcm = await repository.get(machineUUID);

    DeviceFcmSettings? updateDeviceFcmSettings;

    if (currentDeviceFcm == null) {
      talker.info('[MachineFcmSettingsService] Creating new DeviceFcmSettings entry');
      updateDeviceFcmSettings = localDeviceFcm;
    } else {
      final delta = currentDeviceFcm.delta(localDeviceFcm);
      if (!currentDeviceFcm.settings.inheritGlobalSettings) {
        // If the settings are not inherited, we need to remove the settings from the delta to avoid overwriting them
        delta.remove('settings');
      }

      String? fcmToken = delta['fcmToken'];
      if (fcmToken?.isEmpty == true) {
        // If the token is empty, we should not update it
        delta.remove('fcmToken');
      }

      if (delta.isNotEmpty) {
        talker.info('[MachineFcmSettingsService] Updating DeviceFcmSettings entry with delta: $delta');
        updateDeviceFcmSettings = currentDeviceFcm.applyDelta(delta);
      }
    }

    // If the settings have changed, update them
    if (updateDeviceFcmSettings != null) {
      await repository.update(machineUUID, updateDeviceFcmSettings);
      talker.info('[MachineFcmSettingsService] DeviceFcmSettings entry written to machine');
    } else {
      talker.info('[MachineFcmSettingsService] No changes detected');
    }

    return updateDeviceFcmSettings ?? currentDeviceFcm;
  }

  /// Removes orphaned FCM entries associated with the current device's FCM token.
  ///
  /// Orphaned entries can occur when a user adds a printer, removes it, and then adds it again.
  /// This method identifies entries that:
  ///   1. Share the same FCM token as the current device
  ///   2. Reference machines that no longer exist in the user's list of machines
  ///
  /// For each orphaned entry found:
  ///   - A warning is logged
  ///   - The entry is deleted from the repository
  ///
  /// This cleanup prevents notification routing issues and ensures only valid
  /// machine-to-device connections remain on the printer.
  ///
  /// @param token the current FCM token of the device(Phone, Tablet, etc.)
  /// @return A [Future] that completes when all orphaned entries are deleted
  Future<void> clearOrphanDeviceFcm(String currentToken) async {
    talker.info('[MachineFcmSettingsService] Cleaning up orphaned FCM entries');

    final allFcmEntries = await repository.all();
    final allMachines = await machineService.fetchAllMachines();

    // Find all orphaned entries -> Entries with the same token, but not saved on the phone aka. not present in allMachines
    final filteredFcmEntries = {
      for (final entry in allFcmEntries.entries)
        if (entry.value.fcmToken == currentToken && !allMachines.any((machine) => machine.uuid == entry.key)) entry.key
    };

    for (String uuid in filteredFcmEntries) {
      talker.warning(
          '[MachineFcmSettingsService@$machineUUID] Found an old DeviceFcmSettings entry with uuid $uuid that is not present anymore');
      repository.delete(uuid).ignore(); // We don't care about the result
    }
  }

  /// Updates notification settings for a machine
  ///
  /// This method allows updating one or more notification preferences in a single call
  /// while maintaining all other settings. It handles timestamp updates and ensures
  /// proper persistence of the changes.
  ///
  /// Any parameter left as null will keep its existing value.
  ///
  /// @return The updated DeviceFcmSettings object
  Future<DeviceFcmSettings> updateNotificationSettings({
    DeviceFcmSettings? currentSettings,
    bool? inheritGlobalSettings,
    bool? androidProgressbar,
    double? progress,
    Set<PrintState>? states,
    String? snapshotWebcam,
    Set<String>? excludeFilamentSensors,
    bool removeSnapshotWebcam = false,
  }) async {
    // Get the current settings
    currentSettings ??= await repository.get(machineUUID);

    if (currentSettings == null) {
      throw ArgumentError('Cannot update settings: No existing settings found for machine');
    }

    final now = DateTime.now();

    // Create updated settings with only the fields that were specified
    final updatedSettings = currentSettings.copyWith(
      lastModified: now,
      settings: currentSettings.settings.copyWith(
        lastModified: now,
        inheritGlobalSettings: inheritGlobalSettings ?? currentSettings.settings.inheritGlobalSettings,
        androidProgressbar: androidProgressbar ?? currentSettings.settings.androidProgressbar,
        progress: progress ?? currentSettings.settings.progress,
        states: states ?? currentSettings.settings.states,
        snapshotWebcam: snapshotWebcam ?? currentSettings.settings.snapshotWebcam?.unless(removeSnapshotWebcam),
        excludeFilamentSensors: excludeFilamentSensors ?? currentSettings.settings.excludeFilamentSensors,
      ),
    );

    // Update in repository
    await repository.update(machineUUID, updatedSettings);

    // Log what was changed
    final changedFields = [
      if (inheritGlobalSettings != null) 'inheritGlobalSettings',
      if (androidProgressbar != null) 'androidProgressbar',
      if (progress != null) 'progress',
      if (states != null) 'states',
      if (snapshotWebcam != null) 'snapshotWebcam',
      if (excludeFilamentSensors != null) 'excludeFilamentSensors',
    ];

    talker.info('[MachineFcmSettingsService] Updated settings for $machineUUID: ${changedFields.join(', ')}');

    return updatedSettings;
  }
}
