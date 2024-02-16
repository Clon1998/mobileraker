/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:uuid/uuid.dart';

import '../../network/moonraker_database_client.dart';
import '../model/moonraker_db/webcam_info.dart';
import 'webcam_info_repository.dart';

class WebcamInfoRepositoryLegacy extends WebcamInfoRepository {
  WebcamInfoRepositoryLegacy(this._databaseService);

  final MoonrakerDatabaseClient _databaseService;

  @override
  Future<List<WebcamInfo>> fetchAll() async {
    Map<String, dynamic>? json = await _databaseService.getDatabaseItem('mobileraker', key: 'webcams');
    if (json == null) return [];

    return json
        .map((key, value) {
          return MapEntry(
              key,
              WebcamInfo.fromJson({
                'uuid': key,
                ...value,
              }));
        })
        .values
        .toList(growable: false);
  }

  @override
  Future<void> addOrUpdate(WebcamInfo webcamInfo) async {
    var uuid = (webcamInfo.uuid.isEmpty) ? const Uuid().v4() : webcamInfo.uuid;

    await _databaseService.addDatabaseItem('mobileraker', 'webcams.$uuid', webcamInfo);
  }

  @override
  Future<WebcamInfo> remove(String uuid) async {
    Map<String, dynamic> json = await _databaseService.deleteDatabaseItem('mobileraker', 'webcams.$uuid');

    return WebcamInfo.fromJson({'uuid': uuid, ...json});
  }

  @override
  Future<WebcamInfo> get(String uuid) async {
    Map<String, dynamic> json = await _databaseService.getDatabaseItem('mobileraker', key: 'webcams.$uuid');
    return WebcamInfo.fromJson({'uuid': uuid, ...json});
  }
}
