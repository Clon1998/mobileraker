import 'package:mobileraker/data/data_source/moonraker_database_client.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:mobileraker/data/repository/webcam_info_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'webcam_info_repository_impl.g.dart';

@riverpod
WebcamInfoRepositoryImpl webcamInfoRepository(
    WebcamInfoRepositoryRef ref, String machineUUID) {
  return WebcamInfoRepositoryImpl(
      ref.watch(moonrakerDatabaseClientProvider(machineUUID)));
}

class WebcamInfoRepositoryImpl extends WebcamInfoRepository {
  WebcamInfoRepositoryImpl(this._databaseService);

  final MoonrakerDatabaseClient _databaseService;

  @override
  Future<List<WebcamInfo>> fetchAll() async {
    Map<String, dynamic>? json =
        await _databaseService.getDatabaseItem('webcams');
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
    await _databaseService.addDatabaseItem(
        'webcams', webcamInfo.uuid, webcamInfo);
  }

  @override
  Future<WebcamInfo> remove(String uuid) async {
    Map<String, dynamic> json =
        await _databaseService.deleteDatabaseItem('webcams', uuid);

    return WebcamInfo.fromJson({'uuid': uuid, ...json});
  }

  @override
  Future<WebcamInfo> get(String uuid) async {
    Map<String, dynamic> json =
        await _databaseService.getDatabaseItem('webcams', key: uuid);
    return WebcamInfo.fromJson({'uuid': uuid, ...json});
  }
}
