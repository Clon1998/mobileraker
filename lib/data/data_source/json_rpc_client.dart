import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mobileraker/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';

enum ClientState { disconnected, connecting, connected, error }

typedef RpcCallback = Function(Map<String, dynamic> response,
    {Map<String, dynamic>? err});

class JRpcError implements Exception {
  JRpcError(this.code, this.message);

  final int code;

  final String message;

  @override
  String toString() {
    return 'JRpcError{code: $code, message: $message}';
  }
}

class RpcResponse {
  RpcResponse(this.response);

  final Map<String, dynamic> response;
}

class JsonRpcClient {
  JsonRpcClient(this.url, {Duration? defaultTimeout, this.apiKey})
      : _headers = (apiKey != null) ? {'X-Api-Key': apiKey} : const {},
        _defaultTimeout = defaultTimeout ?? const Duration(seconds: 5);

  final String uuid = const Uuid().v4();

  final Duration _defaultTimeout;

  bool _disposed = false;

  String url;

  String? apiKey;

  Exception? errorReason;

  final StreamController<ClientState> _stateStream = StreamController()
    ..add(ClientState.disconnected);

  Stream<ClientState> get stateStream => _stateStream.stream;

  IOWebSocketChannel? _channel;

  StreamSubscription? _channelSub;

  final Map<String, dynamic> _headers;

  bool get hasError => errorReason != null;

  bool get requiresAPIKey {
    if (errorReason != null) {
      if (errorReason is WebSocketException) {
        return (errorReason as WebSocketException)
            .message
            .contains('was not upgraded to websocket');
      }
    }

    return false;
  }

  /// Listeners
  /// List of methods to be called when a JSON RPC notification
  /// comes in.
  ///
  /// Example Resp: {jsonrpc: '2.0', method: <method>, params: [<status_data>]}
  ///
  /// key ->  method, value -> callbacks to be called ince the method arrives
  /// key ='ALL' will be called with all notification messages
  final Map<String, ObserverList<Function>> _methodListeners = {};

  final Map<int, RpcCallback> _requests = {};

  final Map<int, Completer<RpcResponse>> _requestsBlocking = {};

  ClientState _curState = ClientState.disconnected;

  ClientState get curState => _curState;

  set curState(ClientState newState) {
    logger.i('[$url] $curState ➝ $newState');
    if (!_stateStream.isClosed) _stateStream.add(newState);
    _curState = newState;
  }

  /// Initialization the WebSockets connection with the server
  openChannel() {
    _tryConnect();
  }

  /// Closes the WebSocket communication
  reset() {
    _channel?.sink.close(WebSocketStatus.goingAway);
  }

  /// Updates this socket with a new url/api key!
  update(String nurl, String? napiKey) {
    if (url == nurl && apiKey == napiKey) {
      return;
    }
    logger
        .i('Updating WebSocket URL:$url -> $nurl APIKEY: $apiKey -> $napiKey');
    url = nurl;
    apiKey = napiKey;
    openChannel();
  }

  /// Ensures that the ws is still connected.
  /// returns [bool] regarding if the connection still was valid/open!
  bool ensureConnection() {
    if (curState != ClientState.connected &&
        curState != ClientState.connecting) {
      logger.i('[$url] WS not connected! connecting...');
      openChannel();
      return false;
    }
    return true;
  }

  /// Send a Json-Rpc to server using callback for receiving
  sendJsonRpcWithCallback(String method,
      {RpcCallback? onReceive, dynamic params}) {
    var jsonRpc = _constructJsonRPCMessage(method, params: params);
    var mId = jsonRpc['id'];
    if (onReceive != null) _requests[mId] = onReceive;
    logger.d('[$url] Sending for method "$method" with ID $mId');

    _send(jsonEncode(jsonRpc));
  }

  /// Send a JsonRpc using futures
  Future<RpcResponse> sendJRpcMethod(String method, {dynamic params}) async {
    var jsonRpc = _constructJsonRPCMessage(method, params: params);
    var mId = jsonRpc['id'];
    _requests[mId] = _completerCallback;
    var completer = Completer<RpcResponse>();
    _requestsBlocking[mId] = completer;
    logger.d('[$url] Sending(Blocking) for method "$method" with ID $mId');
    _send(jsonEncode(jsonRpc));
    return completer.future;
  }

  /// add a method listener for all(all=*) or given [method]
  addMethodListener(Function(Map<String, dynamic> rawMessage) callback,
      [String method = '*']) {
    _methodListeners.putIfAbsent(method, () => ObserverList()).add(callback);
  }

  _tryConnect() async {
    logger
        .i('Trying to connect to $url with APIkey: `${apiKey ?? 'NO-APIKEY'}`');
    curState = ClientState.connecting;
    reset();
    try {
      WebSocket socket = await WebSocket.connect(url, headers: _headers)
          .timeout(_defaultTimeout);
      if (_disposed) {
        socket.close();
        return;
      }

      socket.pingInterval = _defaultTimeout;
      _channel = IOWebSocketChannel(socket);

      ///
      /// Start listening to notifications / messages
      ///
      _channelSub = _channel!.stream.listen(
        _onChannelMessage,
        onError: _onChannelError,
        onDone: _onChannelClosesNormal,
      );
      // Send a req msg to be sure we are connected!

      // Just ensure to prevent memory leaks!
      if (_stateStream.isClosed) {
        _channelSub?.cancel();
        _channel?.sink.close();
        return;
      }

      if (curState != ClientState.connected) {
        curState = ClientState.connected;
      }
    } on Exception catch (e) {
      _onChannelError(e);
    }
  }

  Map<String, dynamic> _constructJsonRPCMessage(String method,
      {dynamic params}) {
    Map<String, dynamic> json = {};
    json['jsonrpc'] = '2.0';
    // Make sure ID is only used once
    do {
      json['id'] = Random.secure().nextInt(10000);
    } while (_requests.containsKey(json['id']));

    json['method'] = method;
    if (params != null) json['params'] = params;
    return json;
  }

  /// Sends a message to the server
  _send(String message) {
    logger.d('[$url] >>> $message');
    _channel?.sink.add(message);
  }

  /// CB for called for each new message from the channel/ws
  _onChannelMessage(message) {
    Map<String, dynamic> result = jsonDecode(message);
    var mId = result['id'];
    logger.d('[$url] @Rec (messageId: $mId): $message');

    if (result['error'] != null && result['error']['message'] != null) {
      logger.e('[$url] Error message received: $message');
      if (mId != null && _requests.containsKey(mId)) {
        RpcCallback foundHandler = _requests.remove(mId)!;
        foundHandler(result, err: result['error']);
      }
    } else {
      var method = result['method'];

      if (mId != null && _requests.containsKey(mId)) {
        RpcCallback foundHandler = _requests.remove(mId)!;
        foundHandler(result);
      } else if (method != null &&
          (_methodListeners.containsKey(method) ||
              _methodListeners.containsKey('*'))) {
        if (_methodListeners.containsKey(method)) {
          for (var element in _methodListeners[method]!) {
            element(result);
          }
        }
        if (_methodListeners.containsKey('*')) {
          for (var element in _methodListeners['*']!) {
            element(result);
          }
        }
      }
    }
  }

  /// Helper method used as callback if a normal async/future send is requested
  _completerCallback(Map<String, dynamic> response,
      {Map<String, dynamic>? err}) {
    var mId = response['id'];
    logger.d('[$url] Received(Blocking) for id: "$mId"');
    if (_requestsBlocking.containsKey(mId)) {
      Completer completer = _requestsBlocking.remove(mId)!;
      if (err != null) {
        // logger.e('Completing $mId with error $err,\n${StackTrace.current}',);
        completer.completeError(
            JRpcError(err['code'], err['message']), StackTrace.current);
      } else {
        completer.complete(RpcResponse(response));
      }
    } else {
      logger.w('Received response for unknown id "$mId"');
    }
  }

  _onChannelClosesNormal() {
    if (_disposed) return;
    ClientState t = curState;
    if (t != ClientState.error) {
      t = ClientState.disconnected;
    }
    if (!_stateStream.isClosed) curState = t;
    openChannel();
    logger.i('[$url] WS-Stream close normal!');
  }

  _onChannelError(error) {
    if (_disposed) return;
    logger.e('[$url] WS-Stream error: $error');
    errorReason = error;
    curState = ClientState.error;
  }

  dispose() {
    _disposed = true;
    _channelSub?.cancel();
    _requestsBlocking.forEach((key, value) => value.completeError(Future.error(
        'Websocket is closing, request id=$key never got an response!')));
    reset();
    _stateStream.close();
  }
}
