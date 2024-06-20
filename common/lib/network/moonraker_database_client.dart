/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'jrpc_client_provider.dart';

part 'moonraker_database_client.g.dart';

@riverpod
MoonrakerDatabaseClient moonrakerDatabaseClient(MoonrakerDatabaseClientRef ref, String machineUUID) =>
    MoonrakerDatabaseClient(ref, machineUUID);

/// The DatabaseService handles interacts with moonrakers database!
class MoonrakerDatabaseClient {
  MoonrakerDatabaseClient(this.ref, this.machineUUID) : _jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));

  final AutoDisposeRef ref;
  final JsonRpcClient _jsonRpcClient;
  final String machineUUID;

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#list-namespaces
  Future<List<String>> listNamespaces() async {
    _validateClientConnection();
    try {
      RpcResponse blockingResponse = await _jsonRpcClient.sendJRpcMethod('server.database.list');

      List<String> nameSpaces = List.from(blockingResponse.result['namespaces']);
      return nameSpaces;
    } on JRpcError catch (e) {
      logger.e('Error while listing Namespaces $e', e);
    }

    return [];
  }

  /// https://moonraker.readthedocs.io/en/latest/web_api/#get-database-item
  Future<dynamic> getDatabaseItem(String namespace, {String? key, bool throwOnError = false}) async {
    _validateClientConnection();
    logger.i('Getting $key');
    var params = {'namespace': namespace};
    if (key != null) params['key'] = key;
    try {
      RpcResponse blockingResponse = await _jsonRpcClient.sendJRpcMethod('server.database.get_item', params: params);
      return blockingResponse.result['value'];
    } on JRpcError catch (e) {
      if (throwOnError) {
        rethrow;
      }
      logger.w('Could not retrieve key: $key', e, StackTrace.current);
    }
    return null;
  }

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#add-database-item
  Future<dynamic> addDatabaseItem<T>(String namespace, String key, T value) async {
    _validateClientConnection();
    logger.d('Adding $key => $value');
    try {
      RpcResponse blockingResponse = await _jsonRpcClient
          .sendJRpcMethod('server.database.post_item', params: {'namespace': namespace, 'key': key, 'value': value});

      dynamic resultValue = blockingResponse.result['value'];
      if (resultValue is List) return resultValue.cast<T>();
      if (resultValue is T) {
        return resultValue;
      } else {
        return resultValue;
      }
    } on JRpcError catch (e) {
      logger.e('Error while adding to Moonraker-DB: $e', e);
    }

    return null;
  }

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#delete-database-item
  Future<dynamic> deleteDatabaseItem(String namespace, String key) async {
    try {
      _validateClientConnection();
      RpcResponse blockingResponse = await _jsonRpcClient
          .sendJRpcMethod('server.database.delete_item', params: {'namespace': namespace, 'key': key});

      return blockingResponse.result['value'];
    } on JRpcError catch (e) {
      if (e.message.contains('not found')) {
        // Add a log that states that the item was not found and could not be deleted:
        logger.w('Failed to delete item: Item with key \'$key\' not found in namespace \'$namespace\'.');
      } else {
        logger.e('Unexpected error while deleting item with key \'$key\': $e', e);
      }
    }

    return null;
  }

  _validateClientConnection() {
    if (_jsonRpcClient.curState != ClientState.connected) {
      throw WebSocketException('JsonRpcClient is not connected. Target-URL: ${_jsonRpcClient.uri.obfuscate()}');
    }
  }
}
