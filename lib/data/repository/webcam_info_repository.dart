
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';

abstract class WebcamInfoRepository {
  Future<void> addOrUpdate(WebcamInfo webcamInfo);

  Future<WebcamInfo> get(String uuid);

  Future<WebcamInfo> remove(String uuid);

  Future<List<WebcamInfo>> fetchAll();
}