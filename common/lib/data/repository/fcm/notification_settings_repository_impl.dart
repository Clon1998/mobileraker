/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../network/moonraker_database_client.dart';
import '../../model/moonraker_db/fcm/notification_settings.dart';
import '../fcm/notification_settings_repository.dart';

part 'notification_settings_repository_impl.g.dart';

@riverpod
NotificationSettingsRepository notificationSettingsRepository(
        NotificationSettingsRepositoryRef ref, String machineUUID) =>
    NotificationSettingsRepositoryImpl(ref, machineUUID);

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

  @override
  Future<void> updateAndroidProgressbarSettings(String machineId, bool enabled) async {
    await _databaseService.addDatabaseItem(
        'mobileraker', 'fcm.$machineId.settings.lastModified', DateTime.now().toIso8601String());

    await _databaseService.addDatabaseItem('mobileraker', 'fcm.$machineId.settings.androidProgressbar', enabled);
  }

  @override
  Future<void> updateEtaSourcesSettings(String machineId, List<String> sources) async {
    await _databaseService.addDatabaseItem(
        'mobileraker', 'fcm.$machineId.settings.lastModified', DateTime.now().toIso8601String());

    await _databaseService.addDatabaseItem('mobileraker', 'fcm.$machineId.settings.etaSources', sources);
  }
}
