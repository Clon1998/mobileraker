/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

/// The demo printer: a printer record that talks to the in-app simulator
/// ([DemoMoonraker]) instead of a real Moonraker, so people without a printer
/// can try the app.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/jrpc/rpc_response.dart';
import '../../data/model/hive/machine.dart';
import '../../network/json_rpc_client.dart';
import '../../util/logger.dart';
import 'demo_moonraker.dart';

part 'demo_printer.g.dart';

/// Id of the demo printer's record.
const demoMachineUuid = 'mobileraker-demo-printer';

/// The demo printer's record. Its address is never contacted.
Machine demoMachine(String name) => Machine(
      name: name,
      httpUri: Uri.parse('http://demo.mobileraker.invalid'),
      uuid: demoMachineUuid,
    );

bool isDemoMachine(String? uuid) => uuid == demoMachineUuid;

extension DemoMachineX on Machine {
  bool get isDemo => isDemoMachine(uuid);
}

/// The simulator behind the demo printer. The websocket and the HTTP client of
/// the demo printer share it, so files, prints and settings stay consistent.
@riverpod
DemoMoonraker demoMoonraker(Ref ref) {
  final moonraker = DemoMoonraker();
  talker.info('[DemoMoonraker] Started the demo printer simulator');
  ref.onDispose(() {
    talker.info('[DemoMoonraker] Stopped the demo printer simulator');
    moonraker.dispose();
  });
  return moonraker;
}

/// Plugs the pretend Moonraker in where the app expects a websocket client.
class DemoJsonRpcClient extends JsonRpcClient {
  DemoJsonRpcClient(this.moonraker) : super(uri: Uri.parse('ws://demo.mobileraker.invalid/websocket')) {
    moonraker.addListener(_notify);
  }

  final DemoMoonraker moonraker;
  final _listeners = <String, List<RpcMethodListener>>{};
  var _disposed = false;

  void _notify(String method, List<dynamic> params) {
    if (_disposed) return;
    // Through JSON and back, so listeners get exactly the types a real websocket message decodes to.
    final message =
        jsonDecode(jsonEncode({'jsonrpc': '2.0', 'method': method, 'params': params})) as Map<String, dynamic>;
    for (final key in [method, WILDCARD_METHOD]) {
      for (final listener in List.of(_listeners[key] ?? const <RpcMethodListener>[])) {
        listener(message);
      }
    }
  }

  @override
  ClientState get curState => ClientState.connected;

  @override
  Stream<ClientState> get stateStream => Stream.value(ClientState.connected);

  @override
  Future<bool> openChannel() async => true;

  @override
  Future<bool> ensureConnection() async => true;

  @override
  Future<void> identifyConnection(PackageInfo packageInfo, String? apiKey) async {}

  @override
  Future<RpcResponse> sendJRpcMethod(String method, {dynamic params, Duration? timeout}) async {
    // A real printer never answers within the same frame.
    await Future<void>.delayed(const Duration(milliseconds: 15));
    if (_disposed) throw StateError('DemoJsonRpcClient is disposed, method $method never got a response!');
    final result = await moonraker.call(method, params == null ? null : jsonDecode(jsonEncode(params)));
    // Same normalization as the real client: lists are wrapped, `ok` becomes an empty map.
    final normalized = switch (jsonDecode(jsonEncode(result))) {
      'ok' || null => <String, dynamic>{},
      List() && final list => <String, dynamic>{'list': list},
      final Map<String, dynamic> map => map,
      final other => <String, dynamic>{'value': other},
    };
    return RpcResponse(jsonrpc: '2.0', id: 0, result: normalized);
  }

  @override
  void addMethodListener(RpcMethodListener callback, [String method = WILDCARD_METHOD]) =>
      _listeners.putIfAbsent(method, () => []).add(callback);

  @override
  bool removeMethodListener(RpcMethodListener callback, [String? method]) {
    if (method != null) return _listeners[method]?.remove(callback) ?? false;
    var removed = false;
    for (final list in _listeners.values) {
      removed = list.remove(callback) || removed;
    }
    return removed;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    moonraker.removeListener(_notify);
    _listeners.clear();
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

/// Answers the demo printer's HTTP requests (file downloads and uploads) from the simulator.
class DemoHttpClientAdapter implements HttpClientAdapter {
  DemoHttpClientAdapter(this.moonraker);

  final DemoMoonraker moonraker;

  static const _filesPrefix = '/server/files/';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final path = options.uri.path;

    if (options.method == 'POST' && path == '${_filesPrefix}upload') {
      final bytes = await _collect(requestStream);
      final contentType = '${options.headers['content-type'] ?? options.contentType ?? ''}';
      final upload = _parseMultipart(contentType, bytes);
      if (upload == null) return _json({'error': 'Bad request'}, 400);
      final result = moonraker.upload(upload.root, upload.path, upload.content);
      return _json(result, 201);
    }

    if (options.method == 'GET' && path.startsWith(_filesPrefix)) {
      final file = Uri.decodeComponent(path.substring(_filesPrefix.length));
      final content = moonraker.fileContent(file);
      if (content == null) return _json({'error': 'File not found'}, 404);
      final bytes = utf8.encode(content);
      return ResponseBody.fromBytes(bytes, 200, headers: {
        Headers.contentTypeHeader: ['application/octet-stream'],
        Headers.contentLengthHeader: ['${bytes.length}'],
      });
    }

    return _json({'error': 'The demo printer has no ${options.method} $path'}, 404);
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  Future<Uint8List> _collect(Stream<Uint8List>? stream) async {
    final builder = BytesBuilder(copy: false);
    if (stream != null) await stream.forEach(builder.add);
    return builder.takeBytes();
  }

  /// Just enough multipart/form-data to read moonraker's upload form (`root`, `path` and `file`).
  ({String root, String path, String content})? _parseMultipart(String contentType, Uint8List bytes) {
    final boundary = RegExp(r'boundary=("?)([^";]+)\1').firstMatch(contentType)?.group(2);
    if (boundary == null) return null;
    // latin1 maps bytes 1:1, so the file content survives the round trip.
    final body = latin1.decode(bytes);
    String? root;
    String? path;
    String? filename;
    String? content;
    for (final part in body.split('--$boundary')) {
      final split = part.indexOf('\r\n\r\n');
      if (split < 0) continue;
      final headers = part.substring(0, split);
      var value = part.substring(split + 4);
      if (value.endsWith('\r\n')) value = value.substring(0, value.length - 2);
      final name = RegExp(r'name="([^"]*)"').firstMatch(headers)?.group(1);
      switch (name) {
        case 'root':
          root = value.trim();
        case 'path':
          path = value.trim();
        case 'file':
          filename = RegExp(r'filename="([^"]*)"').firstMatch(headers)?.group(1);
          content = utf8.decode(latin1.encode(value), allowMalformed: true);
      }
    }
    if (filename == null || content == null) return null;
    final fullPath = [if (path?.isNotEmpty == true) path, filename].join('/');
    return (root: root ?? 'gcodes', path: fullPath, content: content);
  }
}
