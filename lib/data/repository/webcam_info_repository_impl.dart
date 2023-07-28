/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/jrpc/rpc_response.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:mobileraker/data/repository/webcam_info_repository.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'webcam_info_repository_impl.g.dart';

@riverpod
WebcamInfoRepositoryImpl webcamInfoRepository(
    WebcamInfoRepositoryRef ref, String machineUUID) {
  return WebcamInfoRepositoryImpl(ref.watch(jrpcClientProvider(machineUUID)));
}

class WebcamInfoRepositoryImpl extends WebcamInfoRepository {
  WebcamInfoRepositoryImpl(this._rpcClient);

  final JsonRpcClient _rpcClient;

  @override
  Future<List<WebcamInfo>> fetchAll() async {
    try {
      logger.i('Trying to fetch all webcams from moonraker.');
      RpcResponse response =
          await _rpcClient.sendJRpcMethod('server.webcams.list');
      var webcams = response.result['webcams'] as List<dynamic>?;
      if (webcams == null) return [];
      logger.i('Received ${webcams.length} webcams from moonraker.');
      return webcams
          .map((e) => WebcamInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } on JRpcError catch (e) {
      throw MobilerakerException('Unable to fetch all webcams',
          parentException: e);
    }
  }

  @override
  Future<void> addOrUpdate(WebcamInfo webcamInfo) async {
    try {
      logger
          .i('Trying to update or add webcam with uuid:"${webcamInfo.uuid}".');
      if (webcamInfo.uuid.isNotEmpty && webcamInfo.name != webcamInfo.uuid) {
        await remove(webcamInfo.uuid);
      }

      await _rpcClient.sendJRpcMethod('server.webcams.post_item',
          params: webcamInfo.toJson());
    } on JRpcError catch (e) {
      throw MobilerakerException(
          'Unable to add or update webcam with uuid:${webcamInfo.uuid}',
          parentException: e);
    }
  }

  @override
  Future<WebcamInfo> remove(String uuid) async {
    try {
      logger.i('Trying to delete webcam with uuid:"$uuid".');
      RpcResponse rpcResponse = await _rpcClient
          .sendJRpcMethod('server.webcams.delete_item', params: {'name': uuid});

      return WebcamInfo.fromJson(rpcResponse.result['webcam']);
    } on JRpcError catch (e) {
      throw MobilerakerException('Unable to delete webcam with uuid:$uuid',
          parentException: e);
    }
  }

  @override
  Future<WebcamInfo> get(String uuid) async {
    try {
      logger.i('Trying to fetch webcam with uuid:"$uuid" from moonraker.');
      var response = await _rpcClient
          .sendJRpcMethod('server.webcams.get_item', params: {'name': uuid});
      logger.i('Received webcam with uuid:"$uuid" from moonraker');
      return WebcamInfo.fromJson(response.result['webcam']!);
    } on JRpcError catch (e) {
      throw MobilerakerException('Unable to fetch webcam with uuid:$uuid',
          parentException: e);
    }
  }
}
