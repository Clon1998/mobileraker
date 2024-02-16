/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../network/moonraker_database_client.dart';
import '../../../service/selected_machine_service.dart';
import '../../model/moonraker_db/fcm/notification_settings.dart';
import '../fcm/notification_settings_repository.dart';

part 'notification_settings_repository_impl.g.dart';

@riverpod
NotificationSettingsRepository notificationSettingsRepository(
        NotificationSettingsRepositoryRef ref, String machineUUID) =>
    NotificationSettingsRepositoryImpl(ref, machineUUID);

@riverpod
NotificationSettingsRepository notificationSettingsRepositorySelected(
    NotificationSettingsRepositorySelectedRef ref) {
  return ref.watch(notificationSettingsRepositoryProvider(ref.watch(selectedMachineProvider).requireValue!.uuid));
}

class NotificationSettingsRepositoryImpl extends NotificationSettingsRepository {
  NotificationSettingsRepositoryImpl(AutoDisposeRef ref, String machineUUID)
      : _databaseService = ref.watch(moonrakerDatabaseClientProvider(machineUUID));

  final MoonrakerDatabaseClient _databaseService;

  @override
  Future<NotificationSettings?> get(String machineId) async {
    var json =
        await _databaseService.getDatabaseItem('mobileraker', key: 'fcm.$machineId.settings');
    if (json == null) return null;
    return NotificationSettings.fromJson(json);
  }

  @override
  Future<void> update(String machineId, NotificationSettings notificationSettings) async {
    notificationSettings.lastModified = DateTime.now();

    await _databaseService.addDatabaseItem(
        'mobileraker', 'fcm.$machineId.settings', notificationSettings);
  }

  @override
  Future<void> updateProgressSettings(String machineId, double progress) async {
    await _databaseService.addDatabaseItem(
        'mobileraker', 'fcm.$machineId.settings.lastModified', DateTime.now().toIso8601String());

    await _databaseService.addDatabaseItem(
        'mobileraker', 'fcm.$machineId.settings.progress', progress);
  }

  @override
  Future<void> updateStateSettings(String machineId, Set<PrintState> state) async {
    await _databaseService.addDatabaseItem(
        'mobileraker', 'fcm.$machineId.settings.lastModified', DateTime.now().toIso8601String());

    await _databaseService.addDatabaseItem(
        'mobileraker', 'fcm.$machineId.settings.states', state.map((e) => e.name).toList());
  }
}
