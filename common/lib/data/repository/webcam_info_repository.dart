/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import '../model/moonraker_db/webcam_info.dart';

abstract class WebcamInfoRepository {
  Future<void> addOrUpdate(WebcamInfo webcamInfo);

  Future<WebcamInfo> get(String uuid);

  Future<WebcamInfo> remove(String uuid);

  Future<List<WebcamInfo>> fetchAll();
}
