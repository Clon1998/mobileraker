import 'dart:async';
import 'dart:convert';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/jrpc/rpc_response.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/ref_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'klippy_service.g.dart';

@riverpod
KlippyService klipperService(KlipperServiceRef ref, String machineUUID) {
  return KlippyService(ref, machineUUID);
}

@riverpod
Stream<KlipperInstance> klipper(KlipperRef ref, String machineUUID) {
  return ref.watch(klipperServiceProvider(machineUUID)).klipperStream;
}

@riverpod
KlippyService klipperServiceSelected(
    KlipperServiceSelectedRef ref) {
  return ref.watch(klipperServiceProvider(
      ref.watch(selectedMachineProvider).valueOrNull!.uuid));
}

@riverpod
Stream<KlipperInstance> klipperSelected(
    KlipperSelectedRef ref) async* {
  try {
    var machine = await ref.watchWhereNotNull(selectedMachineProvider);
    StreamController<KlipperInstance> sc = StreamController<KlipperInstance>();
    ref.onDispose(() {
      if (!sc.isClosed) {
        sc.close();
      }
    });
    ref.listen<AsyncValue<KlipperInstance>>(klipperProvider(machine.uuid),
        (previous, next) {
      next.when(
          data: (data) => sc.add(data),
          error: (err, st) => sc.addError(err, st),
          loading: () {
            if (previous != null) ref.invalidateSelf();
          });
    }, fireImmediately: true);

    yield* sc.stream;
  } on StateError catch (_) {
    // Just catch it. It is expected that the future/where might not complete!
  }
}

/// Service managing klippy-server stuff
class KlippyService {
  String ownerUUID;

  KlippyService(this.ref, this.ownerUUID)
      : _jRpcClient = ref.watch(jrpcClientProvider(ownerUUID)) {
    ref.onDispose(dispose);

    _jRpcClient.addMethodListener(_onNotifyKlippyReady, "notify_klippy_ready");
    _jRpcClient.addMethodListener(
        _onNotifyKlippyShutdown, "notify_klippy_shutdown");
    _jRpcClient.addMethodListener(
        _onNotifyKlippyDisconnected, "notify_klippy_disconnected");

    ref.listen(jrpcClientStateProvider(ownerUUID), (previous, next) {
      var data = next as AsyncValue<ClientState>;
      switch (data.valueOrNull) {
        case ClientState.connected:
          _onJrpcConnected();
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

  _onJrpcConnected() async {
    try {
      await Future.wait([_fetchServerInfo(), _fetchPrinterInfo()]).timeout(const Duration(seconds: 5));
    } on JRpcError catch (e, s) {
      logger.w('Error while fetching inital KlippyObject: ${e.message}');

      _current = _current.copyWith(
          klippyConnected: false,
          klippyState: (e.message == 'Unauthorized')
              ? KlipperState.unauthorized
              : KlipperState.error,
          klippyStateMessage: e.message);
    } on TimeoutException catch (e) {
      logger.w('Error while fetching inital KlippyObject: ${e.message}');

      _current = _current.copyWith(
          klippyConnected: false,
          klippyState: (e.message == 'Unauthorized')
              ? KlipperState.unauthorized
              : KlipperState.error,
          klippyStateMessage: e.message);
    }
  }

  Future<void> _fetchServerInfo() async {
    logger.i('>>>Fetching Server.Info');
    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod("server.info");
    _parseServerInfo(rpcResponse.result);
  }

  Future<void> _fetchPrinterInfo() async {
    logger.i(">>>Fetching Printer.Info");
    RpcResponse response = await _jRpcClient.sendJRpcMethod("printer.info");
    _parsePrinterInfo(response.result);
  }

  _parseServerInfo(Map<String, dynamic> result) {
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

  _parsePrinterInfo(Map<String, dynamic> result) {
    logger.i('<<<Received Printer.Info');
    logger.v(
        'PrinterInfo: ${const JsonEncoder.withIndent('  ').convert(result)}');

    KlipperInstance latestKlippy = _current.copyWith(
        klippyState:
            EnumToString.fromString(KlipperState.values, result['state'])!,
        klippyStateMessage: result['state_message']);
    _current = latestKlippy;
  }

  _onNotifyKlippyReady(Map<String, dynamic> m) {
    _current = _current.copyWith(klippyState: KlipperState.ready);
    logger.i('State: notify_klippy_ready');
  }

  _onNotifyKlippyShutdown(Map<String, dynamic> m) {
    _current = _current.copyWith(klippyState: KlipperState.shutdown);
    logger.i('State: notify_klippy_shutdown');
  }

  _onNotifyKlippyDisconnected(Map<String, dynamic> m) {
    _current = _current.copyWith(
        klippyState: KlipperState.disconnected, klippyStateMessage: null);
    logger.i('State: notify_klippy_disconnected: $m');

    Future.delayed(const Duration(seconds: 2)).then((value) =>
        _fetchPrinterInfo()); // need to delay this until its bac connected!
  }

  dispose() {
    _jRpcClient.removeMethodListener(
        _onNotifyKlippyReady, "notify_klippy_ready");
    _jRpcClient.removeMethodListener(
        _onNotifyKlippyShutdown, "notify_klippy_shutdown");
    _jRpcClient.removeMethodListener(
        _onNotifyKlippyDisconnected, "notify_klippy_disconnected");

    _klipperStreamCtler.close();
  }
}
