import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

enum WebSocketState { disconnected, connecting, connected, error }

typedef ReceiveCallback = Function(Map<String, dynamic> response,
    {Map<String, dynamic>? err});

class BlockingResponse {
  final Map<String, dynamic> response;
  final Map<String, dynamic>? err;

  BlockingResponse(this.response, this.err);

  bool get hasError => err != null;

  bool get hasNoError => err == null;
}

class WebSocketWrapper {
  final _logger = getLogger('WebSocketWrapper');

  bool _disposed = false;

  String url;

  String? apiKey;

  IOWebSocketChannel? _channel;

  StreamSubscription? _channelSub;

  final Duration _defaultTimeout;

  Map<String, dynamic> _headers = {};

  Exception? errorReason;

  /// Listeners
  /// List of methods to be called when a JSON RPC notification
  /// comes in.
  ///
  /// Example Resp: {jsonrpc: "2.0", method: <method>, params: [<status_data>]}
  ///
  /// key ->  method, value -> callbacks to be called ince the method arrives
  /// key ='ALL' will be called with all notification messages
  Map<String, ObserverList<Function>> _methodListeners = {};

  Map<int, ReceiveCallback> _requests = {};

  Map<int, Completer<BlockingResponse>> _requestsBlocking = {};

  BehaviorSubject<WebSocketState> stateStream =
      BehaviorSubject.seeded(WebSocketState.disconnected);

  WebSocketWrapper(this.url, this._defaultTimeout, {this.apiKey}) {
    if (apiKey != null) _headers['X-Api-Key'] = apiKey;
    this.initCommunication();
  }

  WebSocketState get _state => stateStream.value;

  set _state(WebSocketState newState) {
    _logger.i("$_state ➝ $newState");
    stateStream.add(newState);
  }

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

  /// ----------------------------------------------------------
  /// Initialization the WebSockets connection with the server
  /// ----------------------------------------------------------
  initCommunication() {
    _tryConnect();
  }

  _tryConnect() {
    _logger
        .i("Trying to connect to $url with APIkey: `${apiKey ?? 'NO-APIKEY'}`");
    _state = WebSocketState.connecting;
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
        _onWSMessage,
        onError: _onWSError,
        onDone: _onWSClosesNormal,
      );
      // Send a req msg to be sure we are connected!

      // Just ensure to prevent memory leaks!
      if (stateStream.isClosed) {
        _channelSub?.cancel();
        _channel?.sink.close();
        return;
      }

      if (_state != WebSocketState.connected) {
        _state = WebSocketState.connected;
      }
    }, onError: _onWSError);
  }

  /// ----------------------------------------------------------
  /// Closes the WebSocket communication
  /// ----------------------------------------------------------
  reset() {
    _channel?.sink.close(status.goingAway);
  }

  update(String nurl, String? napiKey) {
    if (url == nurl && apiKey == napiKey) // No need to update
      return;
    _logger
        .i("Updating WebSocket URL:$url -> $nurl APIKEY: $apiKey -> $napiKey");
    url = nurl;
    apiKey = napiKey;
    initCommunication();
  }

  /// ----------------------------------------------------------
  /// Ensures that the ws is still connected.
  /// returns [bool] regarding if the connection still was valid/open!
  /// ----------------------------------------------------------
  bool ensureConnection() {
    if (_state != WebSocketState.connected &&
        _state != WebSocketState.connecting) {
      _logger.i('WS not connected! connecting...');
      initCommunication();
      return false;
    }
    return true;
  }

  /// ---------------------------------------------------------
  /// Sends a message to the server
  /// ---------------------------------------------------------
  send(String message) {
    _logger.d('>>> $message');
    _channel?.sink.add(message);
  }

  sendJsonRpcMethod(String method,
      {ReceiveCallback? onReceive, dynamic params}) {
    var jsonRpc = _createJsonRPC(method, params: params);
    var mId = jsonRpc['id'];
    if (onReceive != null) _requests[mId] = onReceive;
    _logger.d('Sending for method "$method" with ID $mId');

    send(jsonEncode(jsonRpc));
  }

  Future<BlockingResponse> sendAndReceiveJRpcMethod(String method,
      {dynamic params}) async {
    var jsonRpc = _createJsonRPC(method, params: params);
    var mId = jsonRpc['id'];
    _requests[mId] = _receiveBlocking;
    var completer = Completer<BlockingResponse>();
    _requestsBlocking[mId] = completer;
    _logger.i('Sending(Blocking) for method "$method" with ID $mId');
    send(jsonEncode(jsonRpc));
    return completer.future;
  }

  addMethodListener(Function(Map<String, dynamic> rawMessage) callback,
      [String method = "*"]) {
    _methodListeners.putIfAbsent(method, () => ObserverList()).add(callback);
  }

  Map<String, dynamic> _createJsonRPC(String method, {dynamic params}) {
    Map<String, dynamic> json = Map();
    json['jsonrpc'] = "2.0";
    // Make sure ID is only used once
    do {
      json['id'] = Random.secure().nextInt(10000);
    } while (_requests.containsKey(json['id']));

    json['method'] = method;
    if (params != null) json['params'] = params;
    return json;
  }

  /// ----------------------------------------------------------
  /// Callback which is invoked each time that we are receiving
  /// a message from the server
  /// ----------------------------------------------------------
  _onWSMessage(message) {
    Map<String, dynamic> result = jsonDecode(message);
    var mId = result['id'];
    _logger.d("@Rec (messageId: $mId): $message");

    if (result['error'] != null && result['error']['message'] != null) {
      _logger.e("Error message received: $message");
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

  _receiveBlocking(Map<String, dynamic> response, {Map<String, dynamic>? err}) {
    var mId = response['id'];
    _logger.i('Received(Blocking) for id: "$mId"');
    if (_requestsBlocking.containsKey(mId)) {
      Completer completer = _requestsBlocking.remove(mId)!;
      completer.complete(BlockingResponse(response, err));
    }
  }

  _onWSError(error) {
    _logger.e("WS-Stream error: $error");
    errorReason = error;
    _state = WebSocketState.error;
  }

  _onWSClosesNormal() {
    var t = _state;
    if (t != WebSocketState.error) {
      t = WebSocketState.disconnected;
    }
    if (!stateStream.isClosed) _state = t;
    initCommunication();
    _logger.i("WS-Stream close normal!");
  }

  dispose() {
    _disposed = true;
    _channelSub?.cancel();
    _requestsBlocking.forEach((key, value) => value.completeError(Future.error(
        "Websocket is closing, request id=$key never got an response!")));
    reset();
    stateStream.close();
  }
}
