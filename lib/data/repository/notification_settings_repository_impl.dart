import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/moonraker_database_client.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/moonraker_db/fcm_settings.dart';
import 'package:mobileraker/data/model/moonraker_db/notification_settings.dart';
import 'package:mobileraker/data/repository/fcm_settings_repository.dart';
import 'package:mobileraker/data/repository/notification_settings_repository.dart';
import 'package:mobileraker/service/selected_machine_service.dart';

final notificationSettingsRepositoryProvider = Provider.autoDispose
    .family<NotificationSettingsRepository, String>((ref, machineUUID) {
  return NotificationSettingsRepositoryImpl(ref, machineUUID);
}, name: 'notificationSettingsRepositoryProvider');

final notificationSettingsRepositorySelectedProvider =
    Provider.autoDispose<NotificationSettingsRepository>(
        name: 'notificationSettingsRepositorySelectedProvider', (ref) {
  return ref.watch(notificationSettingsRepositoryProvider(
      ref.watch(selectedMachineProvider).valueOrNull!.uuid));
});

class NotificationSettingsRepositoryImpl
    extends NotificationSettingsRepository {
  NotificationSettingsRepositoryImpl(AutoDisposeRef ref, String machineUUID)
      : _databaseService =
            ref.watch(moonrakerDatabaseClientProvider(machineUUID));

  final MoonrakerDatabaseClient _databaseService;

  @override
  Future<NotificationSettings?> get(String machineId) async {
    var json = await _databaseService.getDatabaseItem('mobileraker',
        key: 'fcm.$machineId.settings');
    if (json == null) return null;
    return NotificationSettings.fromJson(json);
  }

  @override
  Future<void> update(
      String machineId, NotificationSettings notificationSettings) async {
    notificationSettings.lastModified = DateTime.now();

    await _databaseService.addDatabaseItem(
        'mobileraker', 'fcm.$machineId.settings', notificationSettings);
  }

  @override
  Future<void> updateProgressSettings(String machineId, double progress) async {
    await _databaseService.addDatabaseItem(
        'mobileraker',
        'fcm.$machineId.settings.lastModified',
        DateTime.now().toIso8601String());

    await _databaseService.addDatabaseItem(
        'mobileraker', 'fcm.$machineId.settings.progress', progress);
  }

  @override
  Future<void> updateStateSettings(
      String machineId, Set<PrintState> state) async {
    await _databaseService.addDatabaseItem(
        'mobileraker',
        'fcm.$machineId.settings.lastModified',
        DateTime.now().toIso8601String());

    await _databaseService.addDatabaseItem('mobileraker',
        'fcm.$machineId.settings.states', state.map((e) => e.name).toList());
  }
}
