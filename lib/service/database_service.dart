import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/datasource/websocket_wrapper.dart';
import 'package:mobileraker/domain/printer_setting.dart';

/// The DatabaseService handles interacts with moonrakers database!
class DatabaseService {
  final PrinterSetting _owner;
  final _logger = getLogger('DatabaseService');

  DatabaseService(this._owner) {}

  WebSocketWrapper get _webSocket => _owner.websocket;

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#list-namespaces
  Future<List<String>> listNamespaces() async {
    BlockingResponse blockingResponse =
        await _webSocket.sendAndReceiveJRpcMethod("server.database.list");

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

    BlockingResponse blockingResponse = await _webSocket
        .sendAndReceiveJRpcMethod("server.database.get_item", params: params);

    if (blockingResponse.hasNoError &&
        blockingResponse.response.containsKey('result'))
      return blockingResponse.response['result']['value'];
    return null;
  }

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#add-database-item
  Future<dynamic> addDatabaseItem<T>(
      String namespace, String key, T value) async {
    BlockingResponse blockingResponse = await _webSocket
        .sendAndReceiveJRpcMethod("server.database.post_item",
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
    BlockingResponse blockingResponse = await _webSocket
        .sendAndReceiveJRpcMethod("server.database.delete_item",
            params: {"namespace": namespace, "key": key});

    if (blockingResponse.hasNoError &&
        blockingResponse.response.containsKey('result'))
      return blockingResponse.response['result']['value'];

    return null;
  }

  dispose() {}
}
