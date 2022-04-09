import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/datasource/json_rpc_client.dart';
import 'package:mobileraker/domain/hive/machine.dart';

/// The DatabaseService handles interacts with moonrakers database!
class DatabaseService {
  DatabaseService(this._owner);

  final Machine _owner;
  final _logger = getLogger('DatabaseService');

  JsonRpcClient get _jRpcClient => _owner.jRpcClient;

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#list-namespaces
  Future<List<String>> listNamespaces() async {
    RpcResponse blockingResponse =
        await _jRpcClient.sendJRpcMethod("server.database.list");

    if (blockingResponse.hasNoError &&
        blockingResponse.response.containsKey('result')) {
      List<String> nameSpaces =
          List.from(blockingResponse.response['result']['namespaces']);
      return nameSpaces;
    }

    return [];
  }

  /// https://moonraker.readthedocs.io/en/latest/web_api/#get-database-item
  Future<dynamic> getDatabaseItem(String namespace, [String? key]) async {
    var params = {"namespace": namespace};
    if (key != null) params["key"] = key;

    RpcResponse blockingResponse = await _jRpcClient
        .sendJRpcMethod("server.database.get_item", params: params);

    if (blockingResponse.hasNoError &&
        blockingResponse.response.containsKey('result'))
      return blockingResponse.response['result']['value'];
    return null;
  }

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#add-database-item
  Future<dynamic> addDatabaseItem<T>(
      String namespace, String key, T value) async {
    RpcResponse blockingResponse = await _jRpcClient
        .sendJRpcMethod("server.database.post_item",
            params: {"namespace": namespace, "key": key, "value": value});

    if (blockingResponse.hasNoError &&
        blockingResponse.response.containsKey('result')) {
      dynamic value = blockingResponse.response['result']['value'];
      if (value is List)
        return value.cast<T>();
      else
        return value as T;
    }

    return null;
  }

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#delete-database-item
  Future<dynamic> deleteDatabaseItem(String namespace, String key) async {
    RpcResponse blockingResponse = await _jRpcClient
        .sendJRpcMethod("server.database.delete_item",
            params: {"namespace": namespace, "key": key});

    if (blockingResponse.hasNoError &&
        blockingResponse.response.containsKey('result'))
      return blockingResponse.response['result']['value'];

    return null;
  }

  dispose() {}
}
