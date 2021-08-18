import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mobileraker/app/AppSetup.logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

enum WebSocketState { disconnected, connecting, connected, error }

class WebSocketWrapper {
  final _logger = getLogger('WebSocketWrapper');
  final String url;
  final int defaultMaxRetries;
  final Duration _defaultTimeout;
  IOWebSocketChannel? _channel;
  String? apiKey;

  WebSocketWrapper(this.url, this._defaultTimeout,
      {this.defaultMaxRetries = 3, this.apiKey}) {
    this.initCommunication(defaultMaxRetries);
  }

  BehaviorSubject<WebSocketState> stateStream =
      BehaviorSubject.seeded(WebSocketState.disconnected);

  WebSocketState get state => stateStream.value;

  set state(WebSocketState newState) {
    _logger.i("WebSocket: $state ➝ $newState");
    stateStream.add(newState);
  }

  bool get hasError => errorReason != null;

  Exception? errorReason;

  ///
  /// Listeners
  /// List of methods to be called when a JSON RPC notification
  /// comes in.
  ///
  /// Example Resp: {jsonrpc: "2.0", method: <method>, params: [<status_data>]}
  ///
  /// key ->  method, value -> callbacks to be called ince the method arrives
  /// key ='ALL' will be called with all notification messages
  Map<String, ObserverList<Function>> _methodListeners = {};

  Map<int, Function> _requests = {};

  /// ----------------------------------------------------------
  /// Initialization the WebSockets connection with the server
  /// ----------------------------------------------------------
  initCommunication([int? tries]) {
    _tryConnect(tries ?? defaultMaxRetries);
  }

  _tryConnect(int maxRetries) {
    _logger.i("Trying to connect to $url with APIkey: `$apiKey`");
    state = WebSocketState.connecting;
    reset();

    Map<String, dynamic> headers = {};
    if (apiKey != null) headers['X-Api-Key'] = apiKey;
    WebSocket.connect(url.toString(), headers: headers)
        .timeout(_defaultTimeout)
        .then((socket) {
      socket.pingInterval = _defaultTimeout;
      _channel = IOWebSocketChannel(socket);

      ///
      /// Start listening to notifications / messages
      ///
      _channel!.stream.listen(
        _onWSMessage,
        onError: _onWSError,
        onDone: () => _onWSClosesNormal(maxRetries),
      );
      // Send a req msg to be sure we are connected!

      if (state != WebSocketState.connected) {
        state = WebSocketState.connected;
      }
    }, onError: _onWSError);
  }

  /// ----------------------------------------------------------
  /// Closes the WebSocket communication
  /// ----------------------------------------------------------
  reset() {
    _channel?.sink.close(status.goingAway);
  }

  /// ----------------------------------------------------------
  /// Ensures that the ws is still connected.
  /// ----------------------------------------------------------
  ensureConnection() {
    if (state != WebSocketState.connected && state != WebSocketState.connecting)
      initCommunication();
  }

  /// ---------------------------------------------------------
  /// Sends a message to the server
  /// ---------------------------------------------------------
  send(String message) {
    _channel?.sink.add(message);
  }

  sendObject(String method, Function? function, {dynamic params}) {
    var createJsonRPC2 = createJsonRPC(method, params: params);
    if (function != null) _requests[createJsonRPC2['id']] = function;
    send(jsonEncode(createJsonRPC2));
  }

  Map<String, dynamic> createJsonRPC(String method, {dynamic params}) {
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

  addMethodListener(Function callback, [String method = "ALL"]) {
    _methodListeners.putIfAbsent(method, () => ObserverList()).add(callback);
  }

  /// ----------------------------------------------------------
  /// Callback which is invoked each time that we are receiving
  /// a message from the server
  /// ----------------------------------------------------------
  _onWSMessage(message) {
    _logger.v("@Rec: $message");
    var jsonOb = jsonDecode(message);
    if (jsonOb['error'] != null && jsonOb['error']['message'] != null) {
      _logger.e("Error message received: $message");
    } else {
      var mId = jsonOb['id'];
      var method = jsonOb['method'];

      if (mId != null && _requests.isNotEmpty) {
        var foundHandler = _requests[mId];
        if (foundHandler != null) foundHandler(jsonOb['result']);
        _requests.remove(foundHandler);
      } else if (method != null && _methodListeners.isNotEmpty) {
        if (_methodListeners.containsKey(method))
          _methodListeners[method]!.forEach((element) => element(jsonOb));
        if (_methodListeners.containsKey("ALL"))
          _methodListeners["ALL"]!.forEach((element) => element(jsonOb));
      }
    }
  }

  _onWSError(error) {
    _logger.e("WS-Stream error: $error");
    errorReason = error;
    state = WebSocketState.error;
  }

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

  _onWSClosesNormal(int maxRetries) {
    var t = state;
    if (t != WebSocketState.error) {
      t = WebSocketState.disconnected;
    }
    if (!stateStream.isClosed) state = t;
  }
}
