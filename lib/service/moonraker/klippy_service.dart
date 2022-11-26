import 'dart:async';
import 'dart:convert';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/ref_extension.dart';

final klipperServiceProvider = Provider.autoDispose
    .family<KlippyService, String>(name: 'klipperServiceProvider',
        (ref, machineUUID) {
  ref.keepAlive();

  return KlippyService(ref, machineUUID);
});

final klipperProvider = StreamProvider.autoDispose
    .family<KlipperInstance, String>(name: 'klipperProvider',
        (ref, machineUUID) {
  ref.keepAlive();
  return ref.watch(klipperServiceProvider(machineUUID)).klipperStream;
});

final klipperServiceSelectedProvider =
    Provider.autoDispose<KlippyService>(name: 'klipperServiceSelectedProvider', (ref) {
  return ref.watch(klipperServiceProvider(
      ref.watch(selectedMachineProvider).valueOrNull!.uuid));
});
// StreamProvider<KlipperInstance>
final klipperSelectedProvider = StreamProvider.autoDispose<KlipperInstance>(
    name: 'klipperSelectedProvider', (ref) async* {
  try {
    var machine = await ref.watchWhereNotNull(selectedMachineProvider);

    // ToDo: Remove woraround once StreamProvider.stream is fixed!
    yield await ref.read(klipperProvider(machine.uuid).future);
    yield* ref.watch(klipperProvider(machine.uuid).stream);
  } on StateError catch (e, s) {
    // Just catch it. It is expected that the future/where might not complete!
  }
});

/// Service managing klippy-server stuff
class KlippyService {
  KlippyService(this.ref, String machineUUID)
      : _jRpcClient = ref.watch(jrpcClientProvider(machineUUID)) {
    ref.onDispose(dispose);

    _jRpcClient.addMethodListener((m) {
      _current = _current.copyWith(klippyState: KlipperState.ready);
      logger.i('State: notify_klippy_ready');
    }, "notify_klippy_ready");

    _jRpcClient.addMethodListener((m) {
      _current = _current.copyWith(klippyState: KlipperState.shutdown);
      logger.i('State: notify_klippy_shutdown');
    }, "notify_klippy_shutdown");

    _jRpcClient.addMethodListener((m) {
      _current = _current.copyWith(
          klippyState: KlipperState.disconnected, klippyStateMessage: null);
      logger.i('State: notify_klippy_disconnected: $m');

      Future.delayed(const Duration(seconds: 2)).then((value) =>
          _fetchPrinterInfo()); // need to delay this until its bac connected!
    }, "notify_klippy_disconnected");

    ref.listen(jrpcClientStateProvider(machineUUID), (previous, next) {
      var data = next as AsyncValue<ClientState>;
      switch (data.valueOrNull) {
        case ClientState.connected:
          _fetchServerInfo();
          _fetchPrinterInfo();
          break;
        case ClientState.disconnected:
        case ClientState.error:
          _current = _current.copyWith(
              klippyConnected: false, klippyState: KlipperState.error);
          break;
        default:
      }
    });
  }

  final AutoDisposeRef ref;

  final JsonRpcClient _jRpcClient;

  final StreamController<KlipperInstance> _klipperStreamCtler =
      StreamController();

  Stream<KlipperInstance> get klipperStream => _klipperStreamCtler.stream;

  KlipperInstance __current = const KlipperInstance();

  set _current(KlipperInstance nI) {
    __current = nI;
    _klipperStreamCtler.add(nI);
  }

  KlipperInstance get _current => __current;

  bool get isKlippyConnected => _current.klippyConnected;

  restartMCUs() {
    _jRpcClient.sendJsonRpcWithCallback("printer.firmware_restart");
  }

  rebootHost() {
    _jRpcClient.sendJsonRpcWithCallback("machine.reboot");
  }

  shutdownHost() {
    _jRpcClient.sendJsonRpcWithCallback("machine.shutdown");
  }

  restartKlipper() {
    _jRpcClient.sendJsonRpcWithCallback("machine.services.restart",
        params: {'service': 'klipper'});
  }

  restartMoonraker() {
    _jRpcClient.sendJsonRpcWithCallback("machine.services.restart",
        params: {'service': 'moonraker'});
  }

  emergencyStop() {
    _jRpcClient.sendJsonRpcWithCallback("printer.emergency_stop");
  }

  _fetchServerInfo() {
    logger.i('>>>Fetching Server.Info');
    _jRpcClient.sendJsonRpcWithCallback("server.info",
        onReceive: _parseServerInfo);
  }

  _fetchPrinterInfo() {
    logger.i(">>>Fetching Printer.Info");
    _jRpcClient.sendJsonRpcWithCallback("printer.info",
        onReceive: _parsePrinterInfo);
  }

  _parseServerInfo(response, {err}) {
    if (err != null) return;
    var result = response['result'];
    logger.i('<<<Received Server.Info');
    logger
        .v('ServerInfo: ${const JsonEncoder.withIndent('  ').convert(result)}');

    KlipperState state =
        EnumToString.fromString(KlipperState.values, result['klippy_state'])!;
    bool con = result['klippy_connected'];

    List<String> components = (result.containsKey('components'))
        ? result['components'].cast<String>()
        : [];

    List<String> warnings = (result.containsKey('warnings'))
        ? result['warnings'].cast<String>()
        : [];

    KlipperInstance klipperInstance = KlipperInstance(
        klippyConnected: con,
        klippyState: state,
        components: components,
        warnings: warnings);

    _current = klipperInstance;
  }

  _parsePrinterInfo(response, {err}) {
    if (err != null) return;
    var result = response['result'];
    logger.i('<<<Received Printer.Info');
    logger.v(
        'PrinterInfo: ${const JsonEncoder.withIndent('  ').convert(result)}');

    KlipperInstance latestKlippy = _current.copyWith(
        klippyState:
            EnumToString.fromString(KlipperState.values, result['state'])!,
        klippyStateMessage: result['state_message']);
    _current = latestKlippy;
  }

  dispose() {
    _klipperStreamCtler.close();
  }
}
