import 'dart:async';
import 'dart:convert';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/datasource/json_rpc_client.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:rxdart/rxdart.dart';

/// Service managing klippy-server stuff
class KlippyService {
  KlippyService(this._owner) {
    _jRpcClient.addMethodListener((m) {
      KlipperInstance l = _latestKlippy;
      l.klippyState = KlipperState.ready;
      klipperStream.add(l);
      _logger.i('State: notify_klippy_ready');
    }, "notify_klippy_ready");

    _jRpcClient.addMethodListener((m) {
      KlipperInstance l = _latestKlippy;
      l.klippyState = KlipperState.shutdown;
      klipperStream.add(l);
      _logger.i('State: notify_klippy_shutdown');
    }, "notify_klippy_shutdown");

    _jRpcClient.addMethodListener((m) {
      KlipperInstance l = _latestKlippy;
      l.klippyState = KlipperState.disconnected;
      l.klippyStateMessage = null;
      klipperStream.add(l);
      _logger.i('State: notify_klippy_disconnected: $m');

      Future.delayed(Duration(seconds: 2)).then((value) =>
          _fetchPrinterInfo()); // need to delay this until its bac connected!
    }, "notify_klippy_disconnected");

    wsSubscription = _jRpcClient.stateStream.listen((value) {
      switch (value) {
        case ClientState.connected:
          _fetchServerInfo();
          _fetchPrinterInfo();
          break;
        case ClientState.disconnected:
        case ClientState.error:
          KlipperInstance l = _latestKlippy;
          l.klippyState = KlipperState.error;
          l.klippyConnected = false;
          klipperStream.add(l);
          break;
        default:
      }
    });
  }

  late final StreamSubscription<ClientState> wsSubscription;

  final BehaviorSubject<KlipperInstance> klipperStream = BehaviorSubject.seeded(
      KlipperInstance(
          klippyConnected: false, klippyState: KlipperState.startup));

  final Machine _owner;
  final _logger = getLogger('KlippyService');

  JsonRpcClient get _jRpcClient => _owner.jRpcClient;

  //This is not useless since the steam is seeded now!
  KlipperInstance get _latestKlippy {
    return klipperStream.hasValue ? klipperStream.value : KlipperInstance();
  }

  bool get isKlippyConnected =>
      klipperStream.valueOrNull?.klippyConnected ?? false;

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
    _logger.i('>>>Fetching Server.Info');
    _jRpcClient.sendJsonRpcWithCallback("server.info",
        onReceive: _parseServerInfo);
  }

  _fetchPrinterInfo() {
    _logger.i(">>>Fetching Printer.Info");
    _jRpcClient.sendJsonRpcWithCallback("printer.info",
        onReceive: _parsePrinterInfo);
  }

  _parseServerInfo(response, {err}) {
    if (err != null) return;
    var result = response['result'];
    _logger.i('<<<Received Server.Info');
    _logger.v('ServerInfo: ${JsonEncoder.withIndent('  ').convert(result)}');

    KlipperState state =
        EnumToString.fromString(KlipperState.values, result['klippy_state'])!;
    bool con = result['klippy_connected'];

    List<String> plugins =
        (result.containsKey('plugins')) ? result['plugins'].cast<String>() : [];
    KlipperInstance klipperInstance = _latestKlippy;

    klipperInstance.klippyState = state;
    klipperInstance.plugins = plugins;
    klipperInstance.klippyConnected = con;

    klipperStream.add(klipperInstance);
  }

  _parsePrinterInfo(response, {err}) {
    if (err != null) return;
    var result = response['result'];
    _logger.i('<<<Received Printer.Info');
    _logger.v('PrinterInfo: ${JsonEncoder.withIndent('  ').convert(result)}');

    KlipperInstance latestKlippy = _latestKlippy;
    _latestKlippy.klippyState =
        EnumToString.fromString(KlipperState.values, result['state'])!;
    _latestKlippy.klippyStateMessage = result['state_message'];
    klipperStream.add(latestKlippy);
  }

  dispose() {
    wsSubscription.cancel();
    klipperStream.close();
  }
}
