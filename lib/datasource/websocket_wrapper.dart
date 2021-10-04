import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

enum WebSocketState { disconnected, connecting, connected, error }

class WebSocketWrapper {
  final _logger = getLogger('WebSocketWrapper');

  int tries = 0;

  String url;

  String? apiKey;

  IOWebSocketChannel? _channel;

  final Duration _defaultTimeout;

  Map<String, dynamic> _headers = {};

  WebSocketWrapper(this.url, this._defaultTimeout, {this.apiKey}) {
    if (apiKey != null) _headers['X-Api-Key'] = apiKey;
    this.initCommunication();
  }

  BehaviorSubject<WebSocketState> stateStream =
      BehaviorSubject.seeded(WebSocketState.disconnected);

  WebSocketState get _state => stateStream.value;

  set _state(WebSocketState newState) {
    _logger.i("$_state ➝ $newState");
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
  initCommunication() {
    _tryConnect();
  }

  _tryConnect() {
    _logger.i("Trying to connect to $url with APIkey: `${apiKey??'NO-APIKEY'}`");
    _state = WebSocketState.connecting;
    reset();

    WebSocket.connect(url.toString(), headers: _headers)
        .timeout(_defaultTimeout)
        .then((socket) {
      socket.pingInterval = _defaultTimeout;
      _channel = IOWebSocketChannel(socket);
      tries = 0;

      ///
      /// Start listening to notifications / messages
      ///
      _channel!.stream.listen(
        _onWSMessage,
        onError: _onWSError,
        onDone: () => _onWSClosesNormal(),
      );
      // Send a req msg to be sure we are connected!

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
  /// ----------------------------------------------------------
  ensureConnection() {
    if (_state != WebSocketState.connected && _state != WebSocketState.connecting)
      initCommunication();
  }

  /// ---------------------------------------------------------
  /// Sends a message to the server
  /// ---------------------------------------------------------
  send(String message) {
    _channel?.sink.add(message);
  }

  sendObject(String method, Function? function, {dynamic params}) {
    _logger.d('Sending for method "$method"');
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

  addMethodListener(Function(Map<String, dynamic> rawMessage) callback, [String method = "ALL"]) {
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
    _state = WebSocketState.error;
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

  _onWSClosesNormal() {
    var t = _state;
    if (t != WebSocketState.error) {
      t = WebSocketState.disconnected;
    }
    if (!stateStream.isClosed) _state = t;
    initCommunication();
    _logger.i("WS-Stream close normal!");
  }
}
