import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
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
  test('Test without exclude object', () {
    String uuid = "test";
    var mockRpc = MockJsonRpcClient();

    when(mockRpc.addMethodListener(any, 'notify_status_update'))
        .thenReturn(null);
    when(mockRpc.addMethodListener(any, 'notify_gcode_response'))
        .thenReturn(null);
    final respList = File('test_resources/list_resp.json');
    when(mockRpc.sendJRpcMethod('printer.objects.list')).thenAnswer(
        (realInvocation) async =>
            RpcResponse(jsonDecode(respList.readAsStringSync())));
    final respQuery = File('test_resources/query_resp.json');
    var queryAbleObjects = {
      'objects': {
        "configfile": null,
        "temperature_sensor Octopus": null,
        "temperature_sensor raspberry_pi": null,
        "gcode_move": null,
        "print_stats": null,
        "virtual_sdcard": null,
        "heater_bed": null,
        "fan": null,
        "heater_fan toolhead_cooling_fan": null,
        "controller_fan controller_fan": null,
        "toolhead": null,
        "extruder": null
      }
    };
    when(mockRpc.sendJRpcMethod('printer.objects.query',
            params: queryAbleObjects))
        .thenAnswer((realInvocation) async =>
            RpcResponse(jsonDecode(respQuery.readAsStringSync())));
    final respTemp = File('test_resources/temp_store_resp.json');
    when(mockRpc.sendJRpcMethod('server.temperature_store')).thenAnswer(
        (realInvocation) async =>
            RpcResponse(jsonDecode(respTemp.readAsStringSync())));

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
          .overrideWithValue(AsyncValue.data(mockKlipyInstance))
    ]);

    var printerService = container.read(printerServiceProvider(uuid));
  });
}
