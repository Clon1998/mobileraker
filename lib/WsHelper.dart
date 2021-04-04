import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:rxdart/rxdart.dart';
import 'package:simple_logger/simple_logger.dart';
import 'package:web_socket_channel/io.dart';

import 'app/AppSetup.locator.dart';

WebSocketsNotifications sockets = new WebSocketsNotifications();

const String _DEFAULT_SERVER_ADDRESS = "ws://mainsailos.local/websocket";
const int _maxRetries = 3;
const int _retryTime = 5;

enum WebSocketState { disconnected, connecting, connected, error }

class WebSocketsNotifications {
  static final WebSocketsNotifications _sockets =
      new WebSocketsNotifications._internal();
  final logger = locator<SimpleLogger>();

  var lastError;

  BehaviorSubject<WebSocketState> stateStream =
      new BehaviorSubject.seeded(WebSocketState.disconnected);

  WebSocketState get state {
    return stateStream.hasValue
        ? stateStream.value
        : WebSocketState.disconnected;
  }

  set state(WebSocketState newState) {
    stateStream.add(newState);
  }

  String get errorReason => _channel?.closeReason;

  int retries = 0;

  factory WebSocketsNotifications() {
    _sockets.initCommunication();
    return _sockets;
  }

  WebSocketsNotifications._internal();

  ///
  /// The WebSocket "open" channel
  ///
  IOWebSocketChannel _channel;

  ///
  /// Listeners
  /// List of methods to be called when a new message
  /// comes in.
  ///
  /// Example Resp: {jsonrpc: "2.0", method: <method>, params: [<status_data>]}
  ///
  /// key ->  method, value -> callbacks
  Map<String, ObserverList<Function>> _methodListeners = new Map();

  List<MapEntry<int, Function>> _requests = new List();

  /// ----------------------------------------------------------
  /// Initialization the WebSockets connection with the server
  /// ----------------------------------------------------------
  initCommunication([int maxRetries = _maxRetries]) {
    retries = 0;
    _tryConnect(maxRetries);
  }

  _tryConnect(int maxRetries) {
    logger.info("Trying to connect to the WebSocket try: $retries");
    state = WebSocketState.connecting;
    reset();
    var serverAdd = Settings.getValue("klipper.url", _DEFAULT_SERVER_ADDRESS);

    _channel = new IOWebSocketChannel.connect(serverAdd);

    ///
    /// Start listening to new notifications / messages
    ///
    _channel.stream.listen(
      _onReceptionOfMessageFromServer,
      onError: _onWebSocketError,
      onDone: () => _onWebSocketDone(maxRetries),
    );

    _channel.sink.add(jsonEncode(createJsonRPC("printer.info")));
  }

  /// ----------------------------------------------------------
  /// Closes the WebSocket communication
  /// ----------------------------------------------------------
  reset() {
    _channel?.sink?.close();
  }

  /// ---------------------------------------------------------
  /// Sends a message to the server
  /// ---------------------------------------------------------
  send(String message) {
    if (_channel != null) {
      if (_channel.sink != null) {
        _channel.sink.add(message);
      }
    }
  }

  sendObject(String method, Function function, {dynamic params}) {
    var createJsonRPC2 = createJsonRPC(method, params: params);
    if (function != null)
      _requests.add(MapEntry(createJsonRPC2['id'], function));
    send(jsonEncode(createJsonRPC2));
  }

  Map<String, dynamic> createJsonRPC(String method, {dynamic params}) {
    Map<String, dynamic> json = new Map();
    json['jsonrpc'] = "2.0";
    json['id'] = Random.secure().nextInt(10000);
    json['method'] = method;
    if (params != null) json['params'] = params;
    return json;
  }

  addMethodListener(Function callback, [String method = "ALL"]) {
    _methodListeners
        .putIfAbsent(method, () => new ObserverList())
        .add(callback);
  }

  /// ----------------------------------------------------------
  /// Callback which is invoked each time that we are receiving
  /// a message from the server
  /// ----------------------------------------------------------
  _onReceptionOfMessageFromServer(message) {
    if (state != WebSocketState.connected) {
      state = WebSocketState.connected;
      retries = 0;
    }

    // logger.shout("@Rec: $message");
    var jsonOb = jsonDecode(message);
    if (jsonOb['error'] != null && jsonOb['error']['message'] != null) {
      logger.severe("Error message received: $message");
    } else {
      var mId = jsonOb['id'];
      var method = jsonOb['method'];

      if (mId != null && _requests.isNotEmpty) {
        var foundHandler =
            _requests.firstWhere((e) => e.key == mId, orElse: () => null);

        foundHandler?.value(jsonOb['result']);
        _requests.remove(foundHandler);
      } else if (method != null && _methodListeners.isNotEmpty) {
        if (_methodListeners.containsKey(method))
          _methodListeners[method].forEach((element) => element(jsonOb));
        if (_methodListeners.containsKey("ALL"))
          _methodListeners["ALL"].forEach((element) => element(jsonOb));
      }
    }
  }

  _onWebSocketError(error) {
    logger.severe("WS-Stream error: $error");
    lastError = error;

    state = WebSocketState.error;
  }

  void _onWebSocketDone(int maxRetries) {
    logger.shout("###### ON DONE WebSOCKET");
    var t = state;
    if (t != WebSocketState.error) {
      t = WebSocketState.disconnected;
    }

    if (retries < maxRetries) {
      retries++;
      t = WebSocketState.connecting;
      Timer(Duration(seconds: _retryTime),
          () => _tryConnect(maxRetries));
    }
    state = t;
  }
}
