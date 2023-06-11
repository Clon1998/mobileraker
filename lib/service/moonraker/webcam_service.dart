/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/enums/webcam_service_type.dart';
import 'package:mobileraker/data/repository/webcam_info_repository.dart';
import 'package:mobileraker/data/repository/webcam_info_repository_impl.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/util/extensions/ref_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/model/moonraker_db/webcam_info.dart';

part 'webcam_service.g.dart';

const List<WebcamServiceType> supportedCamTypes = [
  WebcamServiceType.mjpegStreamer,
  WebcamServiceType.mjpegStreamerAdaptive,
  WebcamServiceType.uv4lMjpeg
];

@riverpod
WebcamService webcamService(WebcamServiceRef ref, String machineUUID) {
  return WebcamService(ref, machineUUID);
}

@riverpod
Future<List<WebcamInfo>> allWebcamInfos(
    AllWebcamInfosRef ref, String machineUUID) async {
  await ref.watchWhere(jrpcClientStateProvider(machineUUID),
      (c) => c == ClientState.connected, false);
  return ref.watch(webcamServiceProvider(machineUUID)).listWebcamInfos();
}

@riverpod
Future<List<WebcamInfo>> filteredWebcamInfos(
    FilteredWebcamInfosRef ref, String machineUUID) async {
  return (await ref.watch(allWebcamInfosProvider(machineUUID).future))
      .where((element) => supportedCamTypes.contains(element.service))
      .toList(growable: false);
}

@riverpod
Future<WebcamInfo> webcamInfo(
    WebcamInfoRef ref, String machineUUID, String camUUID) async {
  await ref.watchWhere(jrpcClientStateProvider(machineUUID),
      (c) => c == ClientState.connected, false);
  return ref.watch(webcamServiceProvider(machineUUID)).getWebcamInfo(camUUID);
}

/// The WebcamService handles all things related to the webcam API of moonraker.
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#webcam-apis
class WebcamService {
  WebcamService(this.ref, this.machineUUID)
      : _webcamInfoRepository =
            ref.watch(webcamInfoRepositoryProvider(machineUUID));

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
      throw MobilerakerException('Unable to list all webcams',
          parentException: e);
    }
  }

  Future<void> addOrModifyWebcamInfoInBulk(List<WebcamInfo> cams) async {
    logger.i('BULK ADD/MODIFY Webcams "${cams.length}" request...');
    try {
      await Future.wait(cams.map((e) => addOrModifyWebcamInfo(e)));
    } catch (e) {
      throw MobilerakerException(
          'Error while trying to add or modify webcams in bulk!',
          parentException: e);
    }
  }

  Future<WebcamInfo> getWebcamInfo(String uuid) async {
    logger.i('GET Webcam "$uuid" request...');

    try {
      return await _webcamInfoRepository.get(uuid);
    } catch (e) {
      throw MobilerakerException('Unable to get webcam info for $uuid',
          parentException: e);
    }
  }

  Future<void> addOrModifyWebcamInfo(WebcamInfo cam) async {
    logger.i('ADD/MODIFY Webcam "${cam.name}" request...');
    try {
      await _webcamInfoRepository.addOrUpdate(cam);
      ref.invalidate(webcamInfoProvider(machineUUID, cam.uuid));
    } catch (e) {
      throw MobilerakerException(
          'Unable to add/update webcam info for ${cam.uuid}',
          parentException: e);
    }
  }

  Future<List<WebcamInfo>> deleteWebcamInfoInBulk(List<WebcamInfo> cams) {
    logger.i('BULK REMOVE Webcams "${cams.length}" request...');
    try {
      return Future.wait(cams.map((e) => deleteWebcamInfo(e)));
    } catch (e) {
      throw MobilerakerException(
          'Error while trying to add or modify webcams in bulk!',
          parentException: e);
    }
  }

  Future<WebcamInfo> deleteWebcamInfo(WebcamInfo cam) async {
    logger.i('DELETE Webcam "${cam.name}" request...');
    try {
      return await _webcamInfoRepository.remove(cam.uuid);
    } catch (e) {
      throw MobilerakerException('Unable to delete webcam info for ${cam.uuid}',
          parentException: e);
    }
  }
}

// Note this is the impl. based on the Webcam API. However this API is useless.
// It does not offer instant updates.
// /// The WebcamService handles all things related to the webcam API of moonraker.
// /// For more information check out
// /// 1. https://moonraker.readthedocs.io/en/latest/web_api/#webcam-apis
// class WebcamService {
//   WebcamService(AutoDisposeRef ref, String machineUUID)
//       : _jRpcClient = ref.watch(jrpcClientProvider(machineUUID));
//
//   final JsonRpcClient _jRpcClient;
//
//   Future<List<WebcamInfo>> listWebcamInfos() async {
//     logger.i('List Webcams request...');
//
//     try {
//       RpcResponse rpcResponse =
//       await _jRpcClient.sendJRpcMethod('server.webcams.list');
//
//       List<Map<String, dynamic>> cams =
//       rpcResponse.result['webcams'].cast<Map<String, dynamic>>();
//       logger.i('Got webcams: $cams');
//
//       return cams.map((e) => WebcamInfo.fromJson(e)).toList(growable: false);
//     } on JRpcError catch (e) {
//       throw MobilerakerException('Unable to fetch Webcam list',
//           parentException: e);
//     }
//   }
//
//   Future<WebcamInfo> getWebcamInfo(String name) async {
//     logger.i('GET Webcam "$name" request...');
//
//     try {
//       RpcResponse rpcResponse = await _jRpcClient
//           .sendJRpcMethod('server.webcams.get_item', params: {'name': name});
//
//       Map<String, dynamic> camJson = rpcResponse.result['webcam'];
//       logger.i('Got webcam info for "$name": $camJson');
//
//       return WebcamInfo.fromJson(camJson);
//     } on JRpcError catch (e) {
//       throw MobilerakerException('Unable to get webcam info for $name',
//           parentException: e);
//     }
//   }
//
//   Future<WebcamInfo> addOrModifyWebcamInfo(WebcamInfo cam) async {
//     logger.i('ADD/MODIFY Webcam "${cam.name}" request...');
//
//     try {
//       RpcResponse rpcResponse = await _jRpcClient
//           .sendJRpcMethod('server.webcams.post_item', params: cam.toJson());
//
//       Map<String, dynamic> camJson = rpcResponse.result['webcam'];
//       logger.i('Updated webcam info for "${cam.name}": $camJson');
//
//       return WebcamInfo.fromJson(camJson);
//     } on JRpcError catch (e) {
//       throw MobilerakerException('Unable to add or modify webcam ${cam.name}',
//           parentException: e);
//     }
//   }
//
//   Future<WebcamInfo> deleteWebcamInfo(WebcamInfo cam) async {
//     logger.i('DELETE Webcam "${cam.name}" request...');
//
//     if (cam.source != 'database') {
//       throw MobilerakerException(
//           'Can not delete webcams with source ${cam.source}');
//     }
//
//     try {
//       RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod(
//           'server.webcams.delete_item',
//           params: {'name': cam.name});
//
//       Map<String, dynamic> camJson = rpcResponse.result['webcam'];
//       logger.i('Deleted webcam "${cam.name}": $camJson');
//
//       return WebcamInfo.fromJson(camJson);
//     } on JRpcError catch (e) {
//       throw MobilerakerException('Unable to delete webcam ${cam.name}',
//           parentException: e);
//     }
//   }
//
// // Todo Test a webcam, I dont think I need that tbh!
// }
