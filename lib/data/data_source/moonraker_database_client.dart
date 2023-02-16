import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/jrpc/rpc_response.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';

import 'json_rpc_client.dart';

final moonrakerDatabaseClientProvider = Provider.autoDispose
    .family<MoonrakerDatabaseClient, String>(
        (ref, machineUUID) => MoonrakerDatabaseClient(ref, machineUUID),
        name: 'moonrakerDatabaseClientProvider');

/// The DatabaseService handles interacts with moonrakers database!
class MoonrakerDatabaseClient {
  MoonrakerDatabaseClient(this.ref, this.machineUUID)
      : _jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));

  final AutoDisposeRef ref;
  final JsonRpcClient _jsonRpcClient;
  final String machineUUID;

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#list-namespaces
  Future<List<String>> listNamespaces() async {
    _validateClientConnection();
    try {
      RpcResponse blockingResponse =
          await _jsonRpcClient.sendJRpcMethod("server.database.list");

      List<String> nameSpaces =
          List.from(blockingResponse.result['namespaces']);
      return nameSpaces;
    } on JRpcError catch (e) {
      logger.e('Error while listing Namespaces $e', e);
    }

    return [];
  }

  /// https://moonraker.readthedocs.io/en/latest/web_api/#get-database-item
  Future<dynamic> getDatabaseItem(String namespace, {String? key}) async {
    _validateClientConnection();
    logger.i('Getting $key');
    var params = {"namespace": namespace};
    if (key != null) params["key"] = key;
    try {
      RpcResponse blockingResponse = await _jsonRpcClient
          .sendJRpcMethod("server.database.get_item", params: params);

        return blockingResponse.result['value'];
    } on JRpcError catch (e, s) {
      logger.w("Could not retrieve key: $key", e, StackTrace.current);
    }
    return null;
  }

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#add-database-item
  Future<dynamic> addDatabaseItem<T>(
      String namespace, String key, T value) async {
    _validateClientConnection();
    logger.d('Adding $key => $value');
    try {
      RpcResponse blockingResponse = await _jsonRpcClient.sendJRpcMethod(
          "server.database.post_item",
          params: {"namespace": namespace, "key": key, "value": value});

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
      RpcResponse blockingResponse = await _jsonRpcClient.sendJRpcMethod(
          "server.database.delete_item",
          params: {"namespace": namespace, "key": key});

        return blockingResponse.result['value'];
    } on JRpcError catch (e) {
      logger.e('Error while deleting item: $e', e);
    }

    return null;
  }

  _validateClientConnection() {
    if (_jsonRpcClient.curState != ClientState.connected) {
      throw WebSocketException(
          'JsonRpcClient is not connected. Target-URL: ${_jsonRpcClient.uri}');
    }
  }
}
