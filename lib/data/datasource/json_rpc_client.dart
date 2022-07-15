import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

enum ClientState { disconnected, connecting, connected, error }

typedef RpcCallback = Function(Map<String, dynamic> response,
    {Map<String, dynamic>? err});

class JRpcError implements Exception {
  JRpcError(this.code, this.message);

  final int code;

  final String message;
}

class RpcResponse {
  RpcResponse(this.response, this.err);

  final Map<String, dynamic> response;

  final Map<String, dynamic>? err;

  bool get hasError => err != null;

  bool get hasNoError => !hasError;
}

class JsonRpcClient {
  JsonRpcClient(this.url, this._defaultTimeout, {this.apiKey}) {
    if (apiKey != null) _headers['X-Api-Key'] = apiKey;
    this.openChannel();
  }

  final _logger = getLogger('JsonRpcClient');

  final Duration _defaultTimeout;

  bool _disposed = false;

  String url;

  String? apiKey;

  Exception? errorReason;

  BehaviorSubject<ClientState> stateStream =
      BehaviorSubject.seeded(ClientState.disconnected);

  IOWebSocketChannel? _channel;

  StreamSubscription? _channelSub;

  Map<String, dynamic> _headers = {};

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
  Map<String, ObserverList<Function>> _methodListeners = {};

  Map<int, RpcCallback> _requests = {};

  Map<int, Completer<RpcResponse>> _requestsBlocking = {};

  ClientState get _state => stateStream.value;

  set _state(ClientState newState) {
    _logger.i('[$url] $_state ➝ $newState');
    stateStream.add(newState);
  }

  /// Initialization the WebSockets connection with the server
  openChannel() {
    _tryConnect();
  }

  /// Closes the WebSocket communication
  reset() {
    _channel?.sink.close(status.goingAway);
  }

  /// Updates this socket with a new url/api key!
  update(String nurl, String? napiKey) {
    if (url == nurl && apiKey == napiKey) // No need to update
      return;
    _logger
        .i('Updating WebSocket URL:$url -> $nurl APIKEY: $apiKey -> $napiKey');
    url = nurl;
    apiKey = napiKey;
    openChannel();
  }

  /// Ensures that the ws is still connected.
  /// returns [bool] regarding if the connection still was valid/open!
  bool ensureConnection() {
    if (_state != ClientState.connected && _state != ClientState.connecting) {
      _logger.i('[$url] WS not connected! connecting...');
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
    _logger.d('[$url] Sending for method "$method" with ID $mId');

    _send(jsonEncode(jsonRpc));
  }

  /// Send a JsonRpc using futures
  Future<RpcResponse> sendJRpcMethod(String method, {dynamic params}) async {
    var jsonRpc = _constructJsonRPCMessage(method, params: params);
    var mId = jsonRpc['id'];
    _requests[mId] = _completerCallback;
    var completer = Completer<RpcResponse>();
    _requestsBlocking[mId] = completer;
    _logger.d('[$url] Sending(Blocking) for method "$method" with ID $mId');
    _send(jsonEncode(jsonRpc));
    return completer.future;
  }

  /// add a method listener for all(all=*) or given [method]
  addMethodListener(Function(Map<String, dynamic> rawMessage) callback,
      [String method = '*']) {
    _methodListeners.putIfAbsent(method, () => ObserverList()).add(callback);
  }

  _tryConnect() {
    _logger
        .i('Trying to connect to $url with APIkey: `${apiKey ?? 'NO-APIKEY'}`');
    _state = ClientState.connecting;
    reset();

    WebSocket.connect(url.toString(), headers: _headers)
        .timeout(_defaultTimeout)
        .then((socket) {
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
      if (stateStream.isClosed) {
        _channelSub?.cancel();
        _channel?.sink.close();
        return;
      }

      if (_state != ClientState.connected) {
        _state = ClientState.connected;
      }
    }, onError: _onChannelError);
  }

  Map<String, dynamic> _constructJsonRPCMessage(String method,
      {dynamic params}) {
    Map<String, dynamic> json = Map();
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
    _logger.d('[$url] >>> $message');
    _channel?.sink.add(message);
  }

  /// CB for called for each new message from the channel/ws
  _onChannelMessage(message) {
    Map<String, dynamic> result = jsonDecode(message);
    var mId = result['id'];
    _logger.d('[$url] @Rec (messageId: $mId): $message');

    if (result['error'] != null && result['error']['message'] != null) {
      _logger.e('[$url] Error message received: $message');
      if (mId != null && _requests.containsKey(mId)) {
        Function foundHandler = _requests.remove(mId)!;
        foundHandler(result, err: result['error']);
      }
    } else {
      var method = result['method'];

      if (mId != null && _requests.containsKey(mId)) {
        Function foundHandler = _requests.remove(mId)!;
        foundHandler(result);
      } else if (method != null &&
          (_methodListeners.containsKey(method) ||
              _methodListeners.containsKey('*'))) {
        if (_methodListeners.containsKey(method))
          _methodListeners[method]!.forEach((element) => element(result));
        if (_methodListeners.containsKey('*'))
          _methodListeners['*']!.forEach((element) => element(result));
      }
    }
  }

  /// Helper method used as callback if a normal async/future send is requested
  _completerCallback(Map<String, dynamic> response,
      {Map<String, dynamic>? err}) {
    var mId = response['id'];
    _logger.d('[$url] Received(Blocking) for id: "$mId"');
    if (_requestsBlocking.containsKey(mId)) {
      Completer completer = _requestsBlocking.remove(mId)!;
      if (err != null) {
        // _logger.e('Completing $mId with error $err,\n${StackTrace.current}',);
        completer.completeError(JRpcError(err['code'], err['message']));
      } else {
        completer.complete(RpcResponse(response, err));
      }
    }
  }

  _onChannelError(error) {
    _logger.e('[$url] WS-Stream error: $error');
    errorReason = error;
    _state = ClientState.error;
  }

  _onChannelClosesNormal() {
    var t = _state;
    if (t != ClientState.error) {
      t = ClientState.disconnected;
    }
    if (!stateStream.isClosed) _state = t;
    openChannel();
    _logger.i('[$url] WS-Stream close normal!');
  }

  dispose() {
    _disposed = true;
    _channelSub?.cancel();
    _requestsBlocking.forEach((key, value) => value.completeError(Future.error(
        'Websocket is closing, request id=$key never got an response!')));
    reset();
    stateStream.close();
  }
}
