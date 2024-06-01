/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../network/moonraker_database_client.dart';
import '../../model/moonraker_db/fcm/apns.dart';
import 'apns_repository.dart';

part 'apns_repository_impl.g.dart';

@riverpod
APNsRepository apnsRepository(ApnsRepositoryRef ref, String machineUUID) {
  return APNsRepositoryImpl(ref.watch(moonrakerDatabaseClientProvider(machineUUID)));
}

class APNsRepositoryImpl extends APNsRepository {
  APNsRepositoryImpl(this._databaseService);

  final MoonrakerDatabaseClient _databaseService;

  @override
  Future<void> delete(String machineId) async {
    await _databaseService.deleteDatabaseItem('mobileraker', 'fcm.$machineId.apns');
  }

  @override
  Future<APNs?> read(String machineId) async {
    var json = await _databaseService.getDatabaseItem('mobileraker', key: 'fcm.$machineId.apns');

    if (json == null) return null;
    return APNs.fromJson(json);
  }

  @override
  Future<void> write(String machineId, APNs apns) async {
    apns.lastModified = DateTime.now();

    await _databaseService.addDatabaseItem('mobileraker', 'fcm.$machineId.apns', apns);
  }
}
