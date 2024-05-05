/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/model/moonraker_db/webcam_info.dart';
import '../../data/repository/webcam_info_repository.dart';
import '../../network/jrpc_client_provider.dart';

part 'webcam_service.g.dart';

@riverpod
WebcamService webcamService(WebcamServiceRef ref, String machineUUID) {
  return WebcamService(ref, machineUUID);
}

@riverpod
Stream<List<WebcamInfo>> allWebcamInfos(AllWebcamInfosRef ref, String machineUUID) async* {
  final jrpcState = await ref.watch(jrpcClientStateProvider(machineUUID).future);
  if (jrpcState != ClientState.connected) return;

  final webcamInfos = await ref.watch(webcamServiceProvider(machineUUID)).listWebcamInfos();
  ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_webcams_changed'), (previous, next) => ref.invalidateSelf());

  yield webcamInfos;
}

@riverpod
Future<List<WebcamInfo>> allSupportedWebcamInfos(AllSupportedWebcamInfosRef ref, String machineUUID) async {
  return (await ref.watch(allWebcamInfosProvider(machineUUID).future))
      .where((element) => element.service.supported)
      .toList(growable: false);
}

/// The WebcamService handles all things related to the webcam API of moonraker.
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#webcam-apis
class WebcamService {
  WebcamService(this.ref, this.machineUUID)
      : _webcamInfoRepository = ref.watch(webcamInfoRepositoryProvider(machineUUID));

  final String machineUUID;
  final AutoDisposeRef ref;
  final WebcamInfoRepository _webcamInfoRepository;

  Future<List<WebcamInfo>> listWebcamInfos() async {
    logger.i('List Webcams request...');
    try {
      var cams = await _webcamInfoRepository.fetchAll();
      logger.i('Got ${cams.length} webcams');

      return cams;
    } catch (e, s) {
      logger.e('Error while listing cams', e, s);
      throw MobilerakerException('Unable to list all webcams', parentException: e);
    }
  }

  Future<void> addOrModifyWebcamInfoInBulk(List<WebcamInfo> cams) async {
    logger.i('BULK ADD/MODIFY Webcams "${cams.length}" request...');
    try {
      await Future.wait(cams.map((e) => addOrModifyWebcamInfo(e)));
    } catch (e, s) {
      logger.e('Error while saving cams as in Bulk', e, s);
      throw MobilerakerException('Error while trying to add or modify webcams in bulk!',
          parentException: e, parentStack: s);
    }
  }

  Future<WebcamInfo> getWebcamInfo(String uuid) async {
    logger.i('GET Webcam "$uuid" request...');

    try {
      return await _webcamInfoRepository.get(uuid);
    } catch (e) {
      throw MobilerakerException('Unable to get webcam info for $uuid', parentException: e);
    }
  }

  Future<void> addOrModifyWebcamInfo(WebcamInfo cam) async {
    logger.i('ADD/MODIFY Webcam "${cam.name}" request...');
    if (cam.isReadOnly) {
      logger.w('Webcam "${cam.name}" is a config webcam. Skipping...');
      return;
    }

    try {
      await _webcamInfoRepository.addOrUpdate(cam);
    } catch (e) {
      logger.e('Error while saving cam', e);
      throw MobilerakerException('Unable to add/update webcam info for ${cam.uuid}', parentException: e);
    }
  }

  Future<List<WebcamInfo>> deleteWebcamInfoInBulk(List<WebcamInfo> cams) {
    logger.i('BULK REMOVE Webcams "${cams.length}" request...');
    try {
      return Future.wait(cams.map((e) => deleteWebcamInfo(e)));
    } catch (e) {
      throw MobilerakerException('Error while trying to add or modify webcams in bulk!', parentException: e);
    }
  }

  Future<WebcamInfo> deleteWebcamInfo(WebcamInfo cam) async {
    logger.i('DELETE Webcam "${cam.name}" request...');
    try {
      return await _webcamInfoRepository.remove(cam.uuid);
    } catch (e) {
      throw MobilerakerException('Unable to delete webcam info for ${cam.uuid}', parentException: e);
    }
  }
}
