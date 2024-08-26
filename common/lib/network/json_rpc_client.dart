/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/util/extensions/dio_options_extension.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/dto/jrpc/rpc_response.dart';
import '../data/model/hive/machine.dart';
import '../util/extensions/uri_extension.dart';
import '../util/logger.dart';
import '../util/misc.dart';

const String WILDCARD_METHOD = '*';

enum ClientState { disconnected, connecting, connected, error }

enum ClientType { local, octo, manual, obico }

typedef RpcCallback = Function(Map<String, dynamic> response, {Map<String, dynamic>? err});

typedef RpcMethodListener = Function(Map<String, dynamic> response);

class JRpcError implements Exception {
  JRpcError(this.code, this.message);

  final int code;

  final String message;

  @override
  String toString() {
    return 'JRpcError{code: $code, message: $message}';
  }
}

class JRpcTimeoutError extends JRpcError {
  JRpcTimeoutError(String message) : super(-1, message);

  @override
  String toString() {
    return 'JRpcTimeoutError: $message';
  }
}

class JsonRpcClientBuilder {
  JsonRpcClientBuilder();

  factory JsonRpcClientBuilder.fromBaseOptions(BaseOptions options, Machine machine) {
    var baseURL = Uri.parse(options.baseUrl);

    var builder = JsonRpcClientBuilder()
      ..headers = options.headers
      ..clientType = options.clientType
      ..timeout = options.receiveTimeout ?? const Duration(seconds: 10)
      ..uri = baseURL.appendPath('websocket').toWebsocketUri();

    return builder;
  }

  ClientType clientType = ClientType.local;
  Uri? uri;
  Duration timeout = const Duration(seconds: 3);
  Map<String, dynamic> headers = {};
  HttpClient? httpClient;

  JsonRpcClient build() {
    assert(uri != null, 'Provided URI was null');
    return JsonRpcClient(
      uri: uri!,
      timeout: timeout,
      headers: headers,
      clientType: clientType,
      httpClient: httpClient,
    );
  }
}

class JsonRpcClient {
  static const int pingInterval = 15;

  JsonRpcClient({
    required this.uri,
    this.headers = const {},
    HttpClient? httpClient,
    Duration? timeout,
    this.clientType = ClientType.local,
  })  : timeout = timeout ?? const Duration(seconds: 3),
        _httpClient = httpClient ?? HttpClient(),
        assert(['ws', 'wss'].contains(uri.scheme), 'Scheme of provided URI must be WS or WSS!');

  final ClientType clientType;

  final Uri uri;

  final Duration timeout;

  final Map<String, dynamic> headers;

  final HttpClient _httpClient;

  Object? errorReason;

  bool get hasError => errorReason != null;

  bool _disposed = false;

  IOWebSocketChannel? _channel;

  StreamSubscription? _channelSub;

  int _idCounter = 0;

  final BehaviorSubject<ClientState> _stateStream = BehaviorSubject.seeded(ClientState.disconnected);

  Stream<ClientState> get stateStream => _stateStream.stream;

  /// Listeners
  /// List of methods to be called when a JSON RPC notification
  /// comes in.
  ///
  /// Example Resp: {jsonrpc: '2.0', method: <method>, params: [<status_data>]}
  ///
  /// key ->  method, value -> callbacks to be called ince the method arrives
  /// key ='*' will be called with all notification messages
  final Map<String, ObserverList<RpcMethodListener>> _methodListeners = {};

  final Map<int, _Request> _pendingRequests = {};

  ClientState _curState = ClientState.disconnected;

  ClientState get curState => _curState;

  bool _connectionIdentified = false;

  set curState(ClientState newState) {
    if (curState == newState) return;
    logger.i('$logPrefix $curState ➝ $newState');
    if (!_stateStream.isClosed) _stateStream.add(newState);
    _curState = newState;
  }

  /// Initialization the WebSockets connection with the server
  Future<bool> openChannel() {
    return _tryConnect();
  }

  /// Closes the WebSocket communication
  _resetChannel() {
    _channel?.sink.close(WebSocketStatus.goingAway).ignore();
  }

  /// Ensures that the ws is still connected.
  /// returns a future that completes to true if the WS is connected or false once the
  /// reconnection try, if needded is completed!
  Future<bool> ensureConnection() async {
    if (curState != ClientState.connected && curState != ClientState.connecting) {
      logger.i('$logPrefix WS not connected! connecting...');
      return openChannel();
    }
    return true;
  }

  /// Send a JsonRpc using futures
  /// Returns a future that completes to the response of the server
  /// Throws an TimeoutException if the server does not respond in time defined by
  /// [timeout] or the  [this.timeout] of the client

  Future<RpcResponse> sendJRpcMethod(String method, {dynamic params, Duration? timeout}) {
    timeout ??= this.timeout;

    var jsonRpc = _constructJsonRPCMessage(method, params: params);
    var mId = jsonRpc['id'];
    var completer = Completer<RpcResponse>();

    _pendingRequests[mId] = _Request(method, completer, StackTrace.current);

    logger.d('$logPrefix Sending(Blocking) for method "$method" with ID $mId');
    _send(jsonEncode(jsonRpc));
    // If the timeout is zero, dont enforce a timeout
    if (timeout == Duration.zero) {
      return completer.future;
    }
    return completer.future.timeout(timeout).onError<TimeoutException>((error, stackTrace) {
      _pendingRequests.remove(mId);
      throw JRpcTimeoutError('JRpcMethod($method) timed out after ${error.duration?.inSeconds} seconds');
    });
  }

  /// add a method listener for all(all=*) or given [method]
  addMethodListener(RpcMethodListener callback, [String method = WILDCARD_METHOD]) {
    _methodListeners.putIfAbsent(method, () => ObserverList()).add(callback);
  }

  // removes the method that was previously added by addMethodListeners
  bool removeMethodListener(RpcMethodListener callback, [String? method]) {
    if (method == null) {
      var foundListeners = _methodListeners.values.where((element) => element.contains(callback));
      if (foundListeners.isEmpty) return true;
      return foundListeners.map((element) => element.remove(callback)).reduce((value, element) => value || element);
    }
    return _methodListeners[method]?.remove(callback) ?? false;
  }

  Future<void> identifyConnection(PackageInfo packageInfo, String? apiKey) async {
    if (_connectionIdentified) return;

    logger.i('$logPrefix Identifying connection');
    _connectionIdentified = true;

    try {
      await sendJRpcMethod(
        'server.connection.identify',
        params: {
          'client_name': 'Mobileraker-${Platform.operatingSystem}',
          'version': '${packageInfo.version}-${packageInfo.buildNumber}',
          'type': Platform.isMacOS || Platform.isWindows ? 'desktop' : 'mobile',
          'url': 'www.mobileraker.com',
          if (apiKey != null) 'api_key': apiKey,
        },
      );
    } catch (e) {
      logger.e('$logPrefix Error while identifying connection: $e');
    }
  }

  Future<bool> _tryConnect() async {
    logger.i('$logPrefix Trying to connect');
    curState = ClientState.connecting;
    _resetChannel();

    logger.i('$logPrefix Using headers $headersLogSafe');
    logger.i('$logPrefix Using timeout $timeout');

    // Since obico is not closing/terminating the websocket connection in case of statusCode errors like limit reached, we need to send a good old http request.
    if (clientType == ClientType.obico) {
      var obicoValid = await _obicoConnectionIsValid(_httpClient);
      if (!obicoValid) {
        logger.i('$logPrefix Obico connection is not valid, aborting opening of websocket');
        return false;
      }
    }

    if (_disposed) {
      logger.i('$logPrefix Client is already disposed, aborting opening of websocket');
      curState = ClientState.disconnected;
      return false;
    }

    final IOWebSocketChannel ioChannel;
    try {
      ioChannel = IOWebSocketChannel.connect(
        uri,
        headers: headers,
        pingInterval: const Duration(seconds: pingInterval),
        connectTimeout: timeout,
        customClient: _httpClient,
      );
    } catch (e) {
      if (e case StateError(message: "Client is closed")) {
        logger.e('$logPrefix HTTPClient is closed, aborting opening of websocket');
        //TODO: We need to get a new HttpClient here...
      }

      logger.e('$logPrefix Error while connecting IOWebSocketChannel: $e');
      _updateError(e);
      return false;
    }

    _channel = ioChannel;

    ///
    /// Start listening to notifications / messages
    ///
    _channelSub = ioChannel.stream.listen(
      _onChannelMessage,
      onError: _onChannelError,
      onDone: () => _onChannelDone(ioChannel),
    );

    return ioChannel.ready.then((value) {
      curState = ClientState.connected;
      logger.i('$logPrefix IOWebSocketChannel reported READY!');
      return true;
    }, onError: (_, __) {
      logger.i('$logPrefix IOWebSocketChannel reported NOT READY!');
      return false;
    });
  }

  Map<String, dynamic> _constructJsonRPCMessage(String method, {dynamic params}) =>
      {'jsonrpc': '2.0', 'id': _idCounter++, 'method': method, if (params != null) 'params': params};

  /// Sends a message to the server
  _send(String message) {
    logger.d('$logPrefix >>> $message');
    _channel?.sink.add(message);
  }

  int _recivdBytes = 0;

  /// CB for called for each new message from the channel/ws
  _onChannelMessage(message) {
    Map<String, dynamic> result = jsonDecode(message);
    int? mId = result['id'];
    String? method = result['method'];
    Map<String, dynamic>? error = result['error'];
    logger.d('$logPrefix @Rec (messageId: $mId, method: $method): $message');

    if (kDebugMode) {
      final int messageLength = message.length;
      _recivdBytes += messageLength;
      // logger.i('$logPrefix ${message.length}@Rec  (Total: $_recivdBytes) (messageId: $mId, method: $method)');
    }

    if (method != null) {
      _methodListeners[method]?.forEach((e) => e(result));
      _methodListeners[WILDCARD_METHOD]?.forEach((e) => e(result));
    } else if (error != null || mId != null) {
      _completerCallback(result, err: error);
    }
  }

  /// Helper method used as callback if a normal async/future send is requested
  _completerCallback(Map<String, dynamic> response, {Map<String, dynamic>? err}) {
    var mId = response['id'];
    logger.d('$logPrefix Received(Blocking) for id: "$mId"');
    if (_pendingRequests.containsKey(mId)) {
      var request = _pendingRequests.remove(mId)!;
      if (err != null) {
        // logger.e('Completing $mId with error $err,\n${StackTrace.current}',);
        request.completer.completeError(JRpcError(err['code'], err['message']), request.stacktrace);
      } else {
        response = switch (response['result']) {
          // do some trickery here because the gcode response (Why idk) returns `result:ok` instead of an empty map/wrapped in a map..
          'ok' => {...response, 'result': <String, dynamic>{}},
          // Some trickery for spoolman API
          List() => {
              ...response,
              'result': <String, dynamic>{'list': response['result']}
            },
          _ => response
        };

        request.completer.complete(RpcResponse.fromJson(response));
      }
    } else {
      logger.w('$logPrefix Received response for unknown id "$mId"');
    }
  }

  _onChannelDone(WebSocketChannel ioChannel) async {
    if (_disposed) {
      logger.i('$logPrefix WS-Stream is DONE!');
      return;
    }
    var closedNormally = await ioChannel.ready.then((value) => true, onError: (_, __) => false);
    if (closedNormally) {
      _onChannelClosedNormally(ioChannel);
    } else {
      _onChannelClosedAbnormally();
    }
  }

  _onChannelClosedNormally(WebSocketChannel ioChannel) {
    var closeCode = ioChannel.closeCode;
    var closeReason = ioChannel.closeReason;

    logger.i('$logPrefix WS-Stream closed normal! Code: $closeCode, Reason: $closeReason');

    ClientState t = curState;
    if (t != ClientState.error) {
      t = ClientState.disconnected;
    }
    if (!_stateStream.isClosed) curState = t;
    // Can not reconnect if the close code is 1002 (protocol error)
    if (closeCode == 1002) {
      logger.i('$logPrefix Reconnecting is not possible, because the close code is 1002 (protocol error)');
      return;
    }
    openChannel();
  }

  _onChannelClosedAbnormally() async {
    logger.i('$logPrefix WS-Stream closed abnormally!');
    // Here we figure out exactly what is the problem!
    var httpUri = uri.toHttpUri();
    try {
      logger.w('$logPrefix Sending GET to ${httpUri.obfuscate()} to determine error reason');
      var request = await _httpClient.openUrl('GET', httpUri);
      headers.forEach((key, value) {
        request.headers.add(key, value);
      });

      HttpClientResponse response = await request.close();
      logger.i('$logPrefix Got Response to determine error reason: ${response.statusCode}');
      verifyHttpResponseCodes(response.statusCode, clientType);
      // openChannel(); // If no exception was thrown, we just try again!
    } catch (e) {
      _updateError(e);
    }
  }

  _onChannelError(error) async {
    logger.w('$logPrefix Got channel error $error');
    // _updateError(error);
  }

  _updateError(error) {
    if (_disposed) return;
    logger.e('$logPrefix WS-Stream error: $error');
    errorReason = error;
    curState = ClientState.error;
  }

  Future<bool> _obicoConnectionIsValid(HttpClient client) async {
    var httpUri = uri.toHttpUri().replace(path: '/server/info');

    try {
      logger.w('$logPrefix Sending GET to ${httpUri.obfuscate()} to determine obico statusCode');

      var request = await client.openUrl('GET', httpUri);
      headers.forEach((key, value) {
        request.headers.add(key, value);
      });
      HttpClientResponse response = await request.close();
      logger.i('$logPrefix Got Response to determine obico statusCode: ${response.statusCode}');

      verifyHttpResponseCodes(response.statusCode, clientType);
    } catch (e) {
      _updateError(e);
      return false;
    }
    return true;
  }

  dispose() async {
    _disposed = true;

    if (_pendingRequests.isNotEmpty) {
      logger.i(
          '$logPrefix Found ${_pendingRequests.length} hanging requests, waiting for them before completly disposing client');
      try {
        await Future.wait(_pendingRequests.values.map((e) => e.completer.future)).timeout(const Duration(seconds: 30));
      } on TimeoutException catch (_) {
        logger.i('$logPrefix Was unable to complete all hanging JRPC requests after 30sec...');
      } on JRpcError catch (_) {
        // Just catch the JRPC errors that might be returned in the futures to prevent async gap errors...
        // These errors should be handled in the respective caller!
      } finally {
        logger.i('$logPrefix All hanging requests finished!');
      }
    }

    _pendingRequests.forEach((key, value) => value.completer.completeError(
        StateError('Websocket is closing, request id=$key, method ${value.method} never got an response!'),
        StackTrace.current));
    _methodListeners.clear();
    _channelSub?.cancel();

    _resetChannel();
    _stateStream.close();
    _httpClient.close();
    logger.i('$logPrefix JsonRpcClient disposed!');
  }

  String get logPrefix => '[$clientType@${uri.obfuscate()} #${identityHashCode(this)}]';

  String get headersLogSafe =>
      '{${headers.entries.map((e) => '${e.key}: ${e.value.toString().obfuscate(5)}').join(', ')}}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonRpcClient &&
          runtimeType == other.runtimeType &&
          clientType == other.clientType &&
          uri == other.uri &&
          timeout == other.timeout &&
          mapEquals(headers, other.headers) &&
          _httpClient == other._httpClient &&
          errorReason == other.errorReason &&
          _disposed == other._disposed &&
          _channel == other._channel &&
          _channelSub == other._channelSub &&
          _idCounter == other._idCounter &&
          _stateStream == other._stateStream &&
          mapEquals(_methodListeners, other._methodListeners) &&
          mapEquals(_pendingRequests, other._pendingRequests) &&
          _curState == other._curState;

  @override
  int get hashCode =>
      clientType.hashCode ^
      uri.hashCode ^
      timeout.hashCode ^
      _httpClient.hashCode ^
      headers.hashCode ^
      errorReason.hashCode ^
      _disposed.hashCode ^
      _channel.hashCode ^
      _channelSub.hashCode ^
      _idCounter.hashCode ^
      _stateStream.hashCode ^
      _methodListeners.hashCode ^
      _pendingRequests.hashCode ^
      _curState.hashCode;
}

class _Request {
  final String method;
  final Completer<RpcResponse> completer;
  final StackTrace stacktrace;

  _Request(this.method, this.completer, this.stacktrace);
}
