/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mobileraker/data/dto/jrpc/rpc_response.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:web_socket_channel/io.dart';

enum ClientState { disconnected, connecting, connected, error }

enum ClientType { local, octo }

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

class JsonRpcClientBuilder {
  JsonRpcClientBuilder();

  factory JsonRpcClientBuilder.fromOcto(Machine machine) {
    var octoEverywhere = machine.octoEverywhere!;
    var localWsUir = Uri.parse(machine.wsUrl);
    var octoUri = Uri.parse(octoEverywhere.url);

    return JsonRpcClientBuilder()
      ..apiKey = machine.apiKey
      ..uri = localWsUir.replace(
          scheme: 'wss',
          port: null, // OE automatically redirects the ports
          host: octoUri.host,
          userInfo:
              '${octoEverywhere.authBasicHttpUser}:${octoEverywhere.authBasicHttpPassword}')
      ..clientType = ClientType.octo;
  }

  factory JsonRpcClientBuilder.fromMachine(Machine machine) {
    return JsonRpcClientBuilder()
      ..uri = Uri.parse(machine.wsUrl)
      ..apiKey = machine.apiKey
      ..trustSelfSignedCertificate = machine.trustUntrustedCertificate
      ..clientType = ClientType.local;
  }

  ClientType clientType = ClientType.local;
  String? apiKey;
  Uri? uri;
  bool trustSelfSignedCertificate = false;
  Duration timeout = const Duration(seconds: 3);

  JsonRpcClient build() {
    assert(uri != null, 'Provided URI was null');

    Map<String, dynamic> headers = {};
    if (apiKey != null) {
      headers['X-Api-Key'] = apiKey;
    }

    return JsonRpcClient(
      uri: uri!,
      timeout: timeout,
      trustSelfSignedCertificate: trustSelfSignedCertificate,
      headers: headers,
      clientType: clientType,
    );
  }
}

// await Future.delayed(Duration(seconds: 5));
class JsonRpcClient {
  JsonRpcClient({
    required this.uri,
    Duration? timeout,
    this.trustSelfSignedCertificate = false,
    this.headers = const {},
    this.clientType = ClientType.local,
  })  : timeout = timeout ?? const Duration(seconds: 3),
        assert(['ws', 'wss'].contains(uri.scheme),
            'Scheme of provided URI must be WS or WSS!');

  final ClientType clientType;

  final Uri uri;

  final Duration timeout;

  final bool trustSelfSignedCertificate;

  final Map<String, dynamic> headers;

  Exception? errorReason;

  bool get hasError => errorReason != null;

  bool _disposed = false;

  IOWebSocketChannel? _channel;

  StreamSubscription? _channelSub;

  final StreamController<ClientState> _stateStream = StreamController()
    ..add(ClientState.disconnected);

  Stream<ClientState> get stateStream => _stateStream.stream;

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
    if (curState == newState) return;
    logger.i('[${identityHashCode(this)}-$uri] $curState ➝ $newState');
    if (!_stateStream.isClosed) _stateStream.add(newState);
    _curState = newState;
  }

  /// Initialization the WebSockets connection with the server
  Future<bool> openChannel() {
    return _tryConnect();
  }

  /// Closes the WebSocket communication
  _resetChannel() {
    _channel?.sink.close(WebSocketStatus.goingAway);
  }

  /// Ensures that the ws is still connected.
  /// returns a future that completes to true if the WS is connected or false once the
  /// reconnection try, if needded is completed!
  Future<bool> ensureConnection() async {
    if (curState != ClientState.connected &&
        curState != ClientState.connecting) {
      logger.i('[$uri] WS not connected! connecting...');
      return openChannel();
    }
    return true;
  }

  /// Send a Json-Rpc to server using callback for receiving
  sendJsonRpcWithCallback(String method,
      {RpcCallback? onReceive, dynamic params}) {
    var jsonRpc = _constructJsonRPCMessage(method, params: params);
    var mId = jsonRpc['id'];
    if (onReceive != null) _requests[mId] = onReceive;
    logger.d('[$uri] Sending for method "$method" with ID $mId');

    _send(jsonEncode(jsonRpc));
  }

  /// Send a JsonRpc using futures
  Future<RpcResponse> sendJRpcMethod(String method, {dynamic params}) async {
    var jsonRpc = _constructJsonRPCMessage(method, params: params);
    var mId = jsonRpc['id'];
    _requests[mId] = _completerCallback;
    var completer = Completer<RpcResponse>();
    _requestsBlocking[mId] = completer;
    logger.d('[$uri] Sending(Blocking) for method "$method" with ID $mId');
    _send(jsonEncode(jsonRpc));
    return completer.future;
  }

  /// add a method listener for all(all=*) or given [method]
  addMethodListener(Function(Map<String, dynamic> rawMessage) callback,
      [String method = '*']) {
    _methodListeners.putIfAbsent(method, () => ObserverList()).add(callback);
  }

  // removes the method that was previously added by addMethodListeners
  bool removeMethodListener(Function(Map<String, dynamic> rawMessage) callback,
      [String? method]) {
    if (method != null) {
      var foundListeners = _methodListeners.values
          .where((element) => element.contains(callback));
      if (foundListeners.isEmpty) return true;
      return foundListeners
          .map((element) => element.remove(callback))
          .reduce((value, element) => value || element);
    }
    return _methodListeners[method]?.remove(callback) ?? false;
  }

  Future<bool> _tryConnect() async {
    logger.i('[${identityHashCode(this)}]Trying to connect to $uri');
    curState = ClientState.connecting;
    _resetChannel();
    try {
      // if (clientType == ClientType.local) {
      //   await Future.delayed(Duration(seconds: 15));
      //   throw Exception("Teeeest");
      // }

      HttpClient httpClient = _constructHttpClient();

      WebSocket socket = await WebSocket.connect(
        uri.toString(),
        headers: headers,
        customClient: httpClient,
      ).timeout(Duration(seconds: timeout.inSeconds + 2))
        ..pingInterval = timeout;

      if (_disposed) {
        socket.close();
        return false;
      }

      var ioChannel = IOWebSocketChannel(socket);
      _channel = ioChannel;

      ///
      /// Start listening to notifications / messages
      ///
      _channelSub = ioChannel.stream.listen(
        _onChannelMessage,
        onError: _onChannelError,
        onDone: () =>
            _onChannelClosesNormal(socket.closeCode, socket.closeReason),
      );

      curState = ClientState.connected;
      return true;
    } catch (e) {
      _onChannelError(e);
      return false;
    }
  }

  HttpClient _constructHttpClient() {
    HttpClient httpClient = HttpClient();
    httpClient.connectionTimeout = timeout;
    if (trustSelfSignedCertificate) {
      // only allow self signed certificates!
      httpClient.badCertificateCallback =
          (cert, host, port) => cert.issuer == cert.subject;
    }
    return httpClient;
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
    logger.d('[$uri] >>> $message');
    _channel?.sink.add(message);
  }

  /// CB for called for each new message from the channel/ws
  _onChannelMessage(message) {
    Map<String, dynamic> result = jsonDecode(message);
    var mId = result['id'];
    logger.d('[$uri] @Rec (messageId: $mId): $message');

    if (result['error'] != null && result['error']['message'] != null) {
      logger.e('[$uri] Error message received: $message');
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
    logger.d('[$uri] Received(Blocking) for id: "$mId"');
    if (_requestsBlocking.containsKey(mId)) {
      Completer completer = _requestsBlocking.remove(mId)!;
      if (err != null) {
        // logger.e('Completing $mId with error $err,\n${StackTrace.current}',);
        completer.completeError(
            JRpcError(err['code'], err['message']), StackTrace.current);
      } else {
        if (response['result'] == 'ok') {
          response = {
            ...response,
            'result': <String, dynamic>{}
          }; // do some trickery here because the gcode response (Why idk) returns `result:ok` instead of an empty map/wrapped in a map..
        }
        completer.complete(RpcResponse.fromJson(response));
      }
    } else {
      logger.w('Received response for unknown id "$mId"');
    }
  }

  _onChannelClosesNormal(int? closeCode, String? closeReason) {
    if (_disposed) {
      logger
          .i('[$uri${identityHashCode(this)}] WS-Stream Subscription is DONE!');
      return;
    }

    logger.i(
        '[$uri${identityHashCode(this)}] WS-Stream closed normal! Code: $closeCode, Reason: $closeReason');

    ClientState t = curState;
    if (t != ClientState.error) {
      t = ClientState.disconnected;
    }
    if (!_stateStream.isClosed) curState = t;
    openChannel();
  }

  _onChannelError(error) async {
    logger.w('Got channel error $error');
    if (error is! WebSocketException) {
      _updateError(error);
      return;
    }
    // Here we figure out exactly what is the problem!
    var httpUri = uri.replace(
      scheme: uri.isScheme("wss") ? "https" : "http",
    );
    var httpClient = _constructHttpClient();
    try {
      logger.w('Sending GET to $httpUri to determine error reason');
      var request = await httpClient.openUrl("GET", httpUri);

      if (uri.userInfo.isNotEmpty) {
        // If the URL contains user information use that for basic
        // authorization.
        String auth = base64Encode(utf8.encode(uri.userInfo));
        request.headers.set(HttpHeaders.authorizationHeader, "Basic $auth");
      }
      HttpClientResponse response = await request.close();
      logger.wtf('Got Response: ${response.statusCode}');
      verifyHttpResponseCodes(response.statusCode, clientType);
      openChannel(); // If no exception was thrown, we just try again!
    } catch (e) {
      _updateError(e);
    }
  }

  _updateError(error) {
    if (_disposed) return;
    logger.e('[$uri${identityHashCode(this)}] WS-Stream error: $error');
    errorReason = error;
    curState = ClientState.error;
  }

  dispose() async {
    _disposed = true;

    if (_requestsBlocking.isNotEmpty) {
      logger.i(
          '$uri${identityHashCode(this)}] Found hanging requests, waiting for them before completly disposing client');
      try {
        await Future.wait(_requestsBlocking.values.map((e) => e.future))
            .timeout(const Duration(seconds: 30));
      } on TimeoutException catch (_) {
        logger.i(
            '$uri${identityHashCode(this)}] Was unable to complete all hanging JRPC requests after 30sec...');
      } on JRpcError catch(_) {
        // Just catch the JRPC errors that might be returned in the futures to prevent async gap errors...
        // These errors should be handled in the respective caller!
      } finally {
        logger.i(
            '$uri${identityHashCode(this)}] All hanging requests finished!');
      }

    }


    _requestsBlocking.forEach((key, value) => value.completeError(Future.error(
        'Websocket is closing, request id=$key never got an response!')));
    _methodListeners.clear();
    _channelSub?.cancel();

    _resetChannel();
    _stateStream.close();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonRpcClient &&
          runtimeType == other.runtimeType &&
          clientType == other.clientType &&
          uri == other.uri &&
          timeout == other.timeout &&
          trustSelfSignedCertificate == other.trustSelfSignedCertificate &&
          mapEquals(headers, other.headers) &&
          errorReason == other.errorReason &&
          _disposed == other._disposed &&
          _channel == other._channel &&
          _channelSub == other._channelSub &&
          _stateStream == other._stateStream &&
          mapEquals(_methodListeners, other._methodListeners) &&
          mapEquals(_requests, other._requests) &&
          mapEquals(_requestsBlocking, other._requestsBlocking) &&
          _curState == other._curState;

  @override
  int get hashCode =>
      clientType.hashCode ^
      uri.hashCode ^
      timeout.hashCode ^
      trustSelfSignedCertificate.hashCode ^
      headers.hashCode ^
      errorReason.hashCode ^
      _disposed.hashCode ^
      _channel.hashCode ^
      _channelSub.hashCode ^
      _stateStream.hashCode ^
      _methodListeners.hashCode ^
      _requests.hashCode ^
      _requestsBlocking.hashCode ^
      _curState.hashCode;
}
