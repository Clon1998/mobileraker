/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A JSON-RPC call recorded by [FakeJsonRpcClient].
typedef RecordedRpcCall = ({String method, dynamic params});

/// A connected [JsonRpcClient] that never opens a socket. Records every call in [calls] and answers with the result
/// registered in [responses] for the method (an empty result otherwise).
///
/// ```dart
/// final client = FakeJsonRpcClient(responses: {'printer.gcode.script': (_) => {}});
/// ... tap ...
/// expect(client.calls.single, (method: 'printer.gcode.script', params: {'script': 'M220 S110'}));
/// ```
class FakeJsonRpcClient extends Fake implements JsonRpcClient {
  FakeJsonRpcClient({
    this.clientType = ClientType.local,
    Map<String, Map<String, dynamic> Function(dynamic params)>? responses,
  }) : responses = responses ?? {};

  @override
  final ClientType clientType;

  /// Results per method name.
  final Map<String, Map<String, dynamic> Function(dynamic params)> responses;

  /// All calls of [sendJRpcMethod], in order.
  final List<RecordedRpcCall> calls = [];

  /// The methods of [calls].
  List<String> get methods => [for (final c in calls) c.method];

  @override
  Uri get uri => Uri.parse('ws://printer.local/websocket');

  @override
  ClientState curState = ClientState.connected;

  @override
  Stream<ClientState> get stateStream => Stream.value(curState);

  @override
  bool get hasError => errorReason != null;

  /// Why the last connection attempt failed (e.g. a `TimeoutException`).
  @override
  Object? errorReason;

  /// How often [openChannel] was called (e.g. by a reconnect button).
  int openChannelCalls = 0;

  @override
  Future<bool> openChannel() async {
    openChannelCalls++;
    return true;
  }

  @override
  Future<bool> ensureConnection() async => true;

  @override
  Future<RpcResponse> sendJRpcMethod(String method, {dynamic params, Duration? timeout}) async {
    calls.add((method: method, params: params));
    return RpcResponse(jsonrpc: '2.0', id: calls.length, result: responses[method]?.call(params) ?? {});
  }

  @override
  void addMethodListener(RpcMethodListener callback, [String method = WILDCARD_METHOD]) {}

  @override
  bool removeMethodListener(RpcMethodListener callback, [String? method]) => true;

  @override
  Future<void> identifyConnection(PackageInfo packageInfo, String? apiKey) async {}
}
