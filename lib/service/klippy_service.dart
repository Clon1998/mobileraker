import 'dart:async';
import 'dart:convert';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/datasource/websocket_wrapper.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:rxdart/rxdart.dart';

///
/// Handley Server connections/services
///
class KlippyService {
  final PrinterSetting _owner;
  final _logger = getLogger('KlippyService');

  final BehaviorSubject<KlipperInstance> klipperStream = BehaviorSubject.seeded(
      KlipperInstance(
          klippyConnected: false, klippyState: KlipperState.startup));

  late final StreamSubscription<WebSocketState> wsSubscription;

  KlippyService(this._owner) {
    _webSocket.addMethodListener((m) {
      KlipperInstance l = _latestKlippy;
      l.klippyState = KlipperState.ready;
      klipperStream.add(l);
      _logger.i('State: notify_klippy_ready');
    }, "notify_klippy_ready");

    _webSocket.addMethodListener((m) {
      KlipperInstance l = _latestKlippy;
      l.klippyState = KlipperState.shutdown;
      klipperStream.add(l);
      _logger.i('State: notify_klippy_shutdown');
    }, "notify_klippy_shutdown");

    _webSocket.addMethodListener((m) {
      KlipperInstance l = _latestKlippy;
      l.klippyState = KlipperState.disconnected;
      l.klippyStateMessage = null;
      klipperStream.add(l);
      _logger.i('State: notify_klippy_disconnected: $m');

      Future.delayed(Duration(seconds: 2)).then((value) =>
          _fetchPrinterInfo()); // need to delay this until its bac connected!
    }, "notify_klippy_disconnected");

    wsSubscription = _webSocket.stateStream.listen((value) {
      switch (value) {
        case WebSocketState.connected:
          _fetchServerInfo();
          _fetchPrinterInfo();
          break;
        case WebSocketState.disconnected:
        case WebSocketState.error:
          KlipperInstance l = _latestKlippy;
          l.klippyState = KlipperState.error;
          l.klippyConnected = false;
          klipperStream.add(l);
          break;
        default:
      }
    });
  }

  void _fetchServerInfo() {
    _logger.i('>>>Fetching Server.Info');
    _webSocket.sendObject("server.info", _parseServerInfo);
  }

  _fetchPrinterInfo() {
    _logger.i(">>>Fetching Printer.Info");
    _webSocket.sendObject("printer.info", _parsePrinterInfo);
  }

  WebSocketWrapper get _webSocket => _owner.websocket;

  //This is not useless since the steam is seeded now!
  KlipperInstance get _latestKlippy {
    return klipperStream.hasValue ? klipperStream.value : KlipperInstance();
  }

  _parseServerInfo(response) {
    _logger.i('<<<Received Server.Info');
    _logger.v('ServerInfo: ${JsonEncoder.withIndent('  ').convert(response)}');

    KlipperState state =
        EnumToString.fromString(KlipperState.values, response['klippy_state'])!;
    bool con = response['klippy_connected'];

    List<String> plugins = (response.containsKey('plugins'))
        ? response['plugins'].cast<String>()
        : [];
    KlipperInstance klipperInstance = _latestKlippy;

    klipperInstance = klipperStream.value;
    klipperInstance.klippyState = state;
    klipperInstance.plugins = plugins;
    klipperInstance.klippyConnected = con;

    klipperStream.add(klipperInstance);
  }

  _parsePrinterInfo(response) {
    _logger.v('PrinterInfo: ${JsonEncoder.withIndent('  ').convert(response)}');

    KlipperInstance latestKlippy = _latestKlippy;
    _latestKlippy.klippyState =
        EnumToString.fromString(KlipperState.values, response['state'])!;
    _latestKlippy.klippyStateMessage = response['state_message'];
    klipperStream.add(latestKlippy);
  }

  restartMCUs() {
    _webSocket.sendObject("printer.firmware_restart", null);
  }

  rebootHost() {
    _webSocket.sendObject("machine.reboot", null);
  }

  shutdownHost() {
    _webSocket.sendObject("machine.shutdown", null);
  }

  restartKlipper() {
    _webSocket.sendObject("machine.services.restart", null,
        params: {'service': 'klipper'});
  }

  restartMoonraker() {
    _webSocket.sendObject("machine.services.restart", null,
        params: {'service': 'moonraker'});
  }

  emergencyStop() {
    _webSocket.sendObject("printer.emergency_stop", null);
  }

  bool get isKlippyConnected =>
      klipperStream.valueOrNull?.klippyConnected ?? false;

  dispose() {
    wsSubscription.cancel();
    klipperStream.close();
  }
}
