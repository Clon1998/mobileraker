import 'dart:convert';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:mobileraker/datasource/websocket_wrapper.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:rxdart/rxdart.dart';

///
/// Handley Server connections/services
///
class KlippyService {
  final WebSocketWrapper _webSocket;
  final _logger = getLogger('KlippyService');

  final BehaviorSubject<KlipperInstance> klipperStream = BehaviorSubject.seeded(
      KlipperInstance(
          klippyConnected: false, klippyState: KlipperState.startup));

  KlippyService(this._webSocket) {
    _webSocket.addMethodListener((m) {
      KlipperInstance l = _getLatestKlippy();
      l.klippyState = KlipperState.ready;
      klipperStream.add(l);
    }, "notify_klippy_ready");

    _webSocket.addMethodListener((m) {
      KlipperInstance l = _getLatestKlippy();
      l.klippyState = KlipperState.shutdown;
      klipperStream.add(l);
    }, "notify_klippy_shutdown");

    _webSocket.addMethodListener((m) {
      KlipperInstance l = _getLatestKlippy();
      l.klippyState = KlipperState.disconnected;
      klipperStream.add(l);
    }, "notify_klippy_disconnected");

    _webSocket.stateStream.listen((value) {
      switch (value) {
        case WebSocketState.connected:
          _webSocket.sendObject("server.info", _parseServerInfo);
          break;
        case WebSocketState.disconnected:
        case WebSocketState.error:
          KlipperInstance l = _getLatestKlippy();
          l.klippyState = KlipperState.error;
          klipperStream.add(l);
          break;
        default:
      }
    });
  }

  //This is not useless since the steam is seeded now!
  KlipperInstance _getLatestKlippy() {
    return klipperStream.hasValue ? klipperStream.value : KlipperInstance();
  }

  _parseServerInfo(response) {
    _logger.v('ServerInfo: ${JsonEncoder.withIndent('  ').convert(response)}');

    KlipperState state =
        EnumToString.fromString(KlipperState.values, response['klippy_state'])!;
    bool con = response['klippy_connected'];
    List<String> plugins = response['plugins'].cast<String>();
    KlipperInstance klipperInstance = _getLatestKlippy();

    klipperInstance = klipperStream.value;
    klipperInstance.klippyState = state;
    klipperInstance.plugins = plugins;
    klipperInstance.klippyConnected = con;

    klipperStream.add(klipperInstance);
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

  bool get isKlippyConnected => klipperStream.valueOrNull?.klippyConnected ?? false;
}
