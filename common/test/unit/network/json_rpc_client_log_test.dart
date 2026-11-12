/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  setUpAll(() {
    talker = Talker(logger: TalkerLogger(settings: TalkerLoggerSettings(level: LogLevel.debug, enableColors: false)));
  });

  String sentLog() => talker.history.map((e) => e.message ?? '').where((m) => m.contains('>>>')).join('\n');

  test('the params of machine.sudo.password are not logged', () async {
    final client = JsonRpcClient(uri: Uri.parse('ws://printer.local/websocket'));

    // Not connected: the request is logged, goes nowhere and times out.
    final request = client.sendJRpcMethod(
      'machine.sudo.password',
      params: {'password': 'raspberry'},
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(request, throwsA(isA<JRpcTimeoutError>()));

    expect(sentLog(), contains('machine.sudo.password'));
    expect(sentLog(), contains('<redacted>'));
    expect(talker.history.map((e) => e.message ?? '').join('\n'), isNot(contains('raspberry')));
  });

  test('other requests are logged as they are sent', () async {
    final client = JsonRpcClient(uri: Uri.parse('ws://printer.local/websocket'));

    final request = client.sendJRpcMethod(
      'machine.update.recover',
      params: {'name': 'klipper', 'hard': false},
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(request, throwsA(isA<JRpcTimeoutError>()));

    expect(sentLog(), contains('"name":"klipper"'));
  });
}
