/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/model/moonraker_db/webcam_info.dart';
import '../../data/repository/webcam_info_repository.dart';
import '../../network/jrpc_client_provider.dart';
import '../payment_service.dart';
import '../setting_service.dart';

part 'webcam_service.g.dart';

@riverpod
WebcamService webcamService(Ref ref, String machineUUID) {
  return WebcamService(ref, machineUUID);
}

@riverpod
Stream<List<WebcamInfo>> allWebcamInfos(Ref ref, String machineUUID) async* {
  ref.keepAliveFor();
  final jrpcState = await ref.watch(jrpcClientStateProvider(machineUUID).future);
  if (jrpcState != ClientState.connected) return;

  final webcamInfos = await ref.watch(webcamServiceProvider(machineUUID)).listWebcamInfos();
  ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_webcams_changed'), (previous, next) => ref.invalidateSelf());

  yield webcamInfos;
}

@riverpod
Future<List<WebcamInfo>> allSupportedWebcamInfos(Ref ref, String machineUUID) async {
  return (await ref.watch(allWebcamInfosProvider(machineUUID).future))
      .where((element) => element.service.supported)
      .toList(growable: false);
}

@riverpod
Future<WebcamInfo?> activeWebcamInfoForMachine(Ref ref, String machineUUID) async {
  final isSupporter = ref.watch(isSupporterProvider);

  final cams = await ref.watch(allSupportedWebcamInfosProvider(machineUUID).future);
  if (cams.isEmpty) {
    return null;
  }

  final webcamIndexKey = CompositeKey.keyWithString(UtilityKeys.webcamIndex, machineUUID);
  final selIndex = ref.watch(intSettingProvider(webcamIndexKey)).clamp(0, cams.length - 1);

  WebcamInfo? previewCam = cams.elementAtOrNull(selIndex);

  // If there is no preview cam or the preview cam is not for supporters or the user is a supporter
  if (previewCam == null || previewCam.service.forSupporters == false || isSupporter) {
    return previewCam;
  }

  // If the user is not a supporter and the cam he selected is for supporters only just select the first cam that is not for supporters
  return cams.firstWhereOrNull((element) => element.service.forSupporters == false);
}

/// The WebcamService handles all things related to the webcam API of moonraker.
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#webcam-apis
class WebcamService {
  WebcamService(this.ref, this.machineUUID)
      : _webcamInfoRepository = ref.watch(webcamInfoRepositoryProvider(machineUUID));

  final String machineUUID;
  final Ref ref;
  final WebcamInfoRepository _webcamInfoRepository;

  Future<List<WebcamInfo>> listWebcamInfos() async {
    talker.info('List Webcams request...');
    try {
      var cams = await _webcamInfoRepository.fetchAll();
      talker.info('Got ${cams.length} webcams');

      return cams;
    } catch (e, s) {
      talker.error('Error while listing cams', e, s);
      throw MobilerakerException('Unable to list all webcams', parentException: e);
    }
  }

  Future<void> addOrModifyWebcamInfoInBulk(List<WebcamInfo> cams) async {
    talker.info('BULK ADD/MODIFY Webcams "${cams.length}" request...');
    try {
      await Future.wait(cams.map((e) => addOrModifyWebcamInfo(e)));
    } catch (e, s) {
      talker.error('Error while saving cams as in Bulk', e, s);
      throw MobilerakerException('Error while trying to add or modify webcams in bulk!',
          parentException: e, parentStack: s);
    }
  }

  Future<WebcamInfo> getWebcamInfo(String uuid) async {
    talker.info('GET Webcam "$uuid" request...');

    try {
      return await _webcamInfoRepository.get(uuid);
    } catch (e) {
      throw MobilerakerException('Unable to get webcam info for $uuid', parentException: e);
    }
  }

  Future<void> addOrModifyWebcamInfo(WebcamInfo cam) async {
    talker.info('ADD/MODIFY Webcam "${cam.name}" request...');
    if (cam.isReadOnly) {
      talker.warning('Webcam "${cam.name}" is a config webcam. Skipping...');
      return;
    }

    try {
      await _webcamInfoRepository.addOrUpdate(cam);
    } catch (e) {
      talker.error('Error while saving cam', e);
      throw MobilerakerException('Unable to add/update webcam info for ${cam.uid}', parentException: e);
    }
  }

  Future<List<WebcamInfo>> deleteWebcamInfoInBulk(List<WebcamInfo> cams) {
    talker.info('BULK REMOVE Webcams "${cams.length}" request...');
    try {
      return Future.wait(cams.map((e) => deleteWebcamInfo(e)));
    } catch (e) {
      throw MobilerakerException('Error while trying to add or modify webcams in bulk!', parentException: e);
    }
  }

  Future<WebcamInfo> deleteWebcamInfo(WebcamInfo cam) async {
    talker.info('DELETE Webcam "${cam.name}" request...');
    try {
      return await _webcamInfoRepository.remove(cam.uid ?? cam.name);
    } catch (e) {
      throw MobilerakerException('Unable to delete webcam info for ${cam.uid}', parentException: e);
    }
  }
}
