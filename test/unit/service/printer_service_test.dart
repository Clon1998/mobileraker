import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/jrpc/rpc_response.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'printer_service_test.mocks.dart';

@GenerateMocks([JsonRpcClient, MachineService, SnackBarService, DialogService])
void main() {
  String uuid = "test";
  setUpAll(() => setupLogger());
  test('Test without exclude object', () {
    var mockRpc = MockJsonRpcClient();
    when(mockRpc.removeMethodListener(any, any)).thenReturn(true);
    when(mockRpc.addMethodListener(any, 'notify_status_update'))
        .thenReturn(null);
    when(mockRpc.addMethodListener(any, 'notify_gcode_response'))
        .thenReturn(null);
    final respList = File('test_resources/list_resp.json');
    when(mockRpc.sendJRpcMethod('printer.objects.list')).thenAnswer(
        (realInvocation) async =>
            RpcResponse.fromJson(jsonDecode(respList.readAsStringSync())));
    final respQuery = File('test_resources/query_resp.json');
    var queryAbleObjects = {
      'objects': {
        "configfile": null,
        "temperature_sensor Octopus": null,
        "temperature_sensor raspberry_pi": null,
        "gcode_move": null,
        "print_stats": null,
        "virtual_sdcard": null,
        "display_status": null,
        "heater_bed": null,
        "fan": null,
        "heater_fan toolhead_cooling_fan": null,
        "controller_fan controller_fan": null,
        "motion_report": null,
        "toolhead": null,
        "extruder": null
      }
    };
    when(mockRpc.sendJRpcMethod('printer.objects.query',
            params: queryAbleObjects))
        .thenAnswer((realInvocation) async =>
            RpcResponse.fromJson(jsonDecode(respQuery.readAsStringSync())));
    final respTemp = File('test_resources/temp_store_resp.json');
    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer(
        (realInvocation) async =>
            RpcResponse.fromJson(jsonDecode(respTemp.readAsStringSync())));

    when(mockRpc.sendJsonRpcWithCallback('printer.objects.subscribe',
            params: queryAbleObjects))
        .thenReturn(null);

    var mockMachineService = MockMachineService();

    when(mockMachineService.updateMacrosInSettings(uuid, [
      "ECHO_RATOS_VARS",
      "RatOS",
      "MAYBE_HOME",
      "PRIME_LINE",
      "PRIME_BLOB",
      "_PARK",
      "M600",
      "UNLOAD_FILAMENT",
      "LOAD_FILAMENT",
      "SET_CENTER_KINEMATIC_POSITION",
      "START_PRINT",
      "_START_PRINT_AFTER_HEATING_BED",
      "_START_PRINT_BED_MESH",
      "_START_PRINT_PARK",
      "_START_PRINT_AFTER_HEATING_EXTRUDER",
      "END_PRINT",
      "_END_PRINT_BEFORE_HEATERS_OFF",
      "_END_PRINT_AFTER_HEATERS_OFF",
      "_END_PRINT_PARK",
      "GENERATE_SHAPER_GRAPHS",
      "MEASURE_COREXY_BELT_TENSION",
      "COMPILE_FIRMWARE",
      "CHANGE_HOSTNAME"
    ])).thenReturn(null);

    var mockSnackBarService = MockSnackBarService();
    var mockDialogService = MockDialogService();

    var mockKlipyInstance = const KlipperInstance(
        klippyConnected: true, klippyState: KlipperState.ready);

    var container = ProviderContainer(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
      machineServiceProvider.overrideWithValue(mockMachineService),
      snackBarServiceProvider.overrideWithValue(mockSnackBarService),
      dialogServiceProvider.overrideWithValue(mockDialogService),
      klipperProvider(uuid)
          .overrideWith((ref) => Stream.value(mockKlipyInstance))
    ]);

    var printerService = container.read(printerServiceProvider(uuid));
  });

  test('Test with exclude object', () {
    var mockRpc = MockJsonRpcClient();
    when(mockRpc.removeMethodListener(any, any)).thenReturn(true);
    when(mockRpc.addMethodListener(any, 'notify_status_update'))
        .thenReturn(null);
    when(mockRpc.addMethodListener(any, 'notify_gcode_response'))
        .thenReturn(null);
    final respList = File(
        'test_resources/service/printer_service/exclude_object_list_resp.json');
    when(mockRpc.sendJRpcMethod('printer.objects.list')).thenAnswer(
        (realInvocation) async =>
            RpcResponse.fromJson(jsonDecode(respList.readAsStringSync())));
    final respQuery = File(
        'test_resources/service/printer_service/exclude_object_query_response.json');
    var queryAbleObjects = {
      'objects': {
        "exclude_object": null,
        "configfile": null,
        "temperature_sensor Octopus": null,
        "temperature_sensor raspberry_pi": null,
        "gcode_move": null,
        "print_stats": null,
        "virtual_sdcard": null,
        "display_status": null,
        "heater_bed": null,
        "fan": null,
        "heater_fan toolhead_cooling_fan": null,
        "controller_fan controller_fan": null,
        "motion_report": null,
        "toolhead": null,
        "extruder": null
      }
    };

    when(mockRpc.sendJRpcMethod('printer.objects.query',
            params: queryAbleObjects))
        .thenAnswer((realInvocation) async =>
            RpcResponse.fromJson(jsonDecode(respQuery.readAsStringSync())));
    when(mockRpc.sendJRpcMethod('server.temperature_store'))
        .thenAnswer((realInvocation) async => const RpcResponse(jsonrpc: "2.0",id: 212,result: {}));

    when(mockRpc.sendJsonRpcWithCallback('printer.objects.subscribe',
            params: queryAbleObjects))
        .thenReturn(null);

    var mockMachineService = MockMachineService();

    when(mockMachineService.updateMacrosInSettings(uuid, [
      "ECHO_RATOS_VARS",
      "RatOS",
      "MAYBE_HOME",
      "PRIME_LINE",
      "PRIME_BLOB",
      "_PARK",
      "M600",
      "UNLOAD_FILAMENT",
      "LOAD_FILAMENT",
      "SET_CENTER_KINEMATIC_POSITION",
      "START_PRINT",
      "_START_PRINT_AFTER_HEATING_BED",
      "_START_PRINT_BED_MESH",
      "_START_PRINT_PARK",
      "_START_PRINT_AFTER_HEATING_EXTRUDER",
      "END_PRINT",
      "_END_PRINT_BEFORE_HEATERS_OFF",
      "_END_PRINT_AFTER_HEATERS_OFF",
      "_END_PRINT_PARK",
      "GENERATE_SHAPER_GRAPHS",
      "MEASURE_COREXY_BELT_TENSION",
      "COMPILE_FIRMWARE",
      "CHANGE_HOSTNAME"
    ])).thenReturn(null);

    var mockSnackBarService = MockSnackBarService();
    var mockDialogService = MockDialogService();

    var mockKlipyInstance = const KlipperInstance(
        klippyConnected: true, klippyState: KlipperState.ready);

    var container = ProviderContainer(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
      machineServiceProvider.overrideWithValue(mockMachineService),
      snackBarServiceProvider.overrideWithValue(mockSnackBarService),
      dialogServiceProvider.overrideWithValue(mockDialogService),
      klipperProvider(uuid)
          .overrideWith((ref) => Stream.value(mockKlipyInstance))
    ]);

    var printerService = container.read(printerServiceProvider(uuid));
  });

  test('Test with valid initialization', () async {
    var mockRpc = MockJsonRpcClient();

    // MethodListener for subscribed object status updates
    when(mockRpc.addMethodListener(any, 'notify_status_update'))
        .thenReturn(null);
    // MethodListener, for gcode responses updates
    when(mockRpc.addMethodListener(any, 'notify_gcode_response'))
        .thenReturn(null);

    when(mockRpc.removeMethodListener(any, 'notify_status_update'))
        .thenReturn(true);
    when(mockRpc.removeMethodListener(any, 'notify_gcode_response'))
        .thenReturn(true);

    var mockSnackBarService = MockSnackBarService();
    var mockMachineService = MockMachineService();
    var mockDialogService = MockDialogService();

    // Initially the klipper service reports that klipper currently is starting/not yet ready

    var mockKlipyyStreamCtl = StreamController<KlipperInstance>()
      ..add(const KlipperInstance(
          klippyConnected: true, klippyState: KlipperState.startup));

    var container = ProviderContainer(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
      machineServiceProvider.overrideWithValue(mockMachineService),
      snackBarServiceProvider.overrideWithValue(mockSnackBarService),
      dialogServiceProvider.overrideWithValue(mockDialogService),
      klipperProvider(uuid).overrideWith((ref) => mockKlipyyStreamCtl.stream)
    ]);

    // ToDO: Do I need tests for the provider? I mean it is basd on the service so??
    // var printer = container.read(printerProvider(uuid));
    // expect(printer, const AsyncValue<Printer>.loading());
    // expect(printer.isLoading, true);
    // expect(printer.hasValue, false);
    var printerService = container.read(printerServiceProvider(uuid));
    verify(mockRpc.addMethodListener(
        any, 'notify_status_update')); // Objects' status updates
    verify(mockRpc.addMethodListener(
        any, 'notify_gcode_response')); // Gcode responses
    expect(printerService.hasCurrent, false);
    expect(printerService.currentOrNull, null);

    when(mockRpc.sendJRpcMethod('printer.objects.list')).thenAnswer(
        (_) async => const RpcResponse(jsonrpc: '2.0', id: 1, result: {
              'objects': ['toolhead']
            }));

    when(mockRpc.sendJRpcMethod('printer.objects.query', params: {
      'objects': {'toolhead': null}
    })).thenAnswer(
        (_) async => const RpcResponse(jsonrpc: '2.0', id: 1, result: {
              'status': {
                "toolhead": {
                  "position": [0, 0, 0, 0],
                  "status": "Ready"
                }
              }
            }));

    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer(
        (_) async => const RpcResponse(jsonrpc: '2.0', id: 1, result: {}));

    when(mockRpc.sendJsonRpcWithCallback('printer.objects.subscribe',
        params: ['toolhead'])).thenReturn(null);

    when(mockMachineService.updateMacrosInSettings(uuid, any)).thenReturn(null);

    mockKlipyyStreamCtl.add(const KlipperInstance(
        klippyConnected: true, klippyState: KlipperState.ready));
    await expectLater(printerService.printerStream, emits(isNotNull));

    verify(mockRpc.sendJRpcMethod('printer.objects.list'));
    verify(mockRpc.sendJRpcMethod('printer.objects.query', params: {
      'objects': ['toolhead']
    }));
  });
}
