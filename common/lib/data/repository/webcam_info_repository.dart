/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/repository/webcam_info_repository_impl.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../network/jrpc_client_provider.dart';
import '../../network/moonraker_database_client.dart';
import '../../service/moonraker/klippy_service.dart';
import '../../util/logger.dart';
import '../model/moonraker_db/webcam_info.dart';
import 'webcam_info_repository_legacy.dart';

part 'webcam_info_repository.g.dart';

@riverpod
WebcamInfoRepository webcamInfoRepository(WebcamInfoRepositoryRef ref, String machineUUID) {
  var moonrakerVersion = ref.watch(klipperProvider(machineUUID).selectAs((data) => data.moonrakerVersion)).valueOrNull;
  // Prior to this commit, there was a bug in moonraker that caused the webcam API to not work properly.
  // https://github.com/Arksine/moonraker/commit/f487de77bc4c2db154299747aefce0ed2354bbf8
  if ((moonrakerVersion?.compareTo(0, 8, 0, 80) ?? 0) < 0) {
    logger.i('Using moonraker db for webcam info repository');
    return WebcamInfoRepositoryLegacy(ref.watch(moonrakerDatabaseClientProvider(machineUUID)));
  }
  logger.i('Using WebcamAPI for webcam info repository');
  return WebcamInfoRepositoryImpl(ref.watch(jrpcClientProvider(machineUUID)));
}

abstract class WebcamInfoRepository {
  Future<void> addOrUpdate(WebcamInfo webcamInfo);

  Future<WebcamInfo> get(String uuid);

  Future<WebcamInfo> remove(String uuid);

  Future<List<WebcamInfo>> fetchAll();
}
