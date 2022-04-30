import 'dart:io';

import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/data/datasource/json_rpc_client.dart';
import 'package:mobileraker/service/selected_machine_service.dart';

/// The DatabaseService handles interacts with moonrakers database!
class MoonrakerDatabaseClient {
  final _logger = getLogger('MoonrakerDatabaseClient');
  final _selectedMachineService = locator<SelectedMachineService>();

  JsonRpcClient get _selectedJRpcClient =>
      _selectedMachineService.selectedMachine.value!.jRpcClient;

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#list-namespaces
  Future<List<String>> listNamespaces([JsonRpcClient? client]) async {
    JsonRpcClient _client = _selectCorrectClient(client);
    RpcResponse blockingResponse =
        await _client.sendJRpcMethod("server.database.list");

    if (blockingResponse.hasNoError &&
        blockingResponse.response.containsKey('result')) {
      List<String> nameSpaces =
          List.from(blockingResponse.response['result']['namespaces']);
      return nameSpaces;
    }

    return [];
  }

  /// https://moonraker.readthedocs.io/en/latest/web_api/#get-database-item
  Future<dynamic> getDatabaseItem(String namespace,
      {String? key, JsonRpcClient? client}) async {
    JsonRpcClient _client = _selectCorrectClient(client);
    _logger.i('Getting $key');
    var params = {"namespace": namespace};
    if (key != null) params["key"] = key;

    RpcResponse blockingResponse = await _client
        .sendJRpcMethod("server.database.get_item", params: params);

    if (blockingResponse.hasNoError &&
        blockingResponse.response.containsKey('result'))
      return blockingResponse.response['result']['value'];
    return null;
  }

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#add-database-item
  Future<dynamic> addDatabaseItem<T>(String namespace, String key, T value,
      [JsonRpcClient? client]) async {
    JsonRpcClient _client = _selectCorrectClient(client);
    _logger.d('Adding $key => $value');
    RpcResponse blockingResponse = await _client.sendJRpcMethod(
        "server.database.post_item",
        params: {"namespace": namespace, "key": key, "value": value});

    if (blockingResponse.hasNoError &&
        blockingResponse.response.containsKey('result')) {
      dynamic value = blockingResponse.response['result']['value'];
      if (value is List)
        return value.cast<T>();
      if (value is T)
        return value;
      else
        return value;

    } else {
      _logger.e('Error while adding to Moonraker-DB: ${blockingResponse.err}');
    }

    return null;
  }

  /// see: https://moonraker.readthedocs.io/en/latest/web_api/#delete-database-item
  Future<dynamic> deleteDatabaseItem(String namespace, String key,
      [JsonRpcClient? client]) async {
    JsonRpcClient _client = _selectCorrectClient(client);
    RpcResponse blockingResponse = await _client.sendJRpcMethod(
        "server.database.delete_item",
        params: {"namespace": namespace, "key": key});

    if (blockingResponse.hasNoError &&
        blockingResponse.response.containsKey('result'))
      return blockingResponse.response['result']['value'];

    return null;
  }

  JsonRpcClient _selectCorrectClient([JsonRpcClient? client]) {
    if (client == null && !_selectedMachineService.selectedMachine.hasValue) {
      throw Exception('No machine/jRpcClient available');
    }
    client ??= _selectedJRpcClient;
    if (client.stateStream.valueOrNull != ClientState.connected) {
      throw WebSocketException('JsonRpcClient is not connected. Target-URL: ${client.url}');
    }
    return client;
  }

  dispose() {}
}
