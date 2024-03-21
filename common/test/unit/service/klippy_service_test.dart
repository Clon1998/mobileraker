/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../test_utils.dart';
import 'klippy_service_test.mocks.dart';

@GenerateMocks([JsonRpcClient])
void main() {
  String uuid = 'test';

  test('Test klippyService init', () {
    setupTestLogger();
    var mockRpc = MockJsonRpcClient();
    when(mockRpc.addMethodListener(any, 'notify_klippy_ready')).thenReturn(null);

    when(mockRpc.addMethodListener(any, 'notify_klippy_shutdown')).thenReturn(null);

    when(mockRpc.addMethodListener(any, 'notify_klippy_disconnected')).thenReturn(null);

    var serverInfoJson =
        '{"jsonrpc": "2.0", "id": 111, "result": {"klippy_connected": true, "klippy_state": "ready", "components": ["klippy_connection", "application", "websockets", "internal_transport", "dbus_manager", "database", "file_manager", "klippy_apis", "secrets", "template", "shell_command", "machine", "data_store", "proc_stats", "job_state", "job_queue", "http_client", "announcements", "webcam", "extensions", "update_manager", "authorization", "octoprint_compat"], "failed_components": [], "registered_directories": ["config", "logs", "gcodes", "config_examples", "docs"], "warnings": [], "websocket_count": 5, "moonraker_version": "v0.8.0-29-g80920dd", "missing_klippy_requirements": [], "api_version": [1, 2, 1], "api_version_string": "1.2.1"}}';

    when(mockRpc.sendJRpcMethod('server.info'))
        .thenAnswer((realInvocation) async => RpcResponse.fromJson(jsonDecode(serverInfoJson)));

    var printerInfoJson =
        '{"jsonrpc": "2.0", "id": 222, "result": {"state_message": "Printer is ready", "klipper_path": "/home/pi/klipper", "config_file": "/home/pi/klipper_config/printer.cfg", "software_version": "v0.11.0-128-g57c4da5e", "hostname": "toasty", "cpu_info": "4 core ARMv7 Processor rev 4 (v7l)", "state": "ready", "python_path": "/home/pi/klippy-env/bin/python", "log_file": "/home/pi/klipper_logs/klippy.log"}}';

    when(mockRpc.sendJRpcMethod('printer.info'))
        .thenAnswer((realInvocation) async => RpcResponse.fromJson(jsonDecode(printerInfoJson)));

    var container = ProviderContainer(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
      jrpcClientStateProvider(uuid).overrideWith((ref) async* {
        yield ClientState.connected;
      })
    ]);

    var klippyService = container.read(klipperServiceProvider(uuid));

    // verify(mockRpc.sendJRpcMethod('server.info'));
    // verify(mockRpc.sendJRpcMethod('printer.info'));
  });
}
