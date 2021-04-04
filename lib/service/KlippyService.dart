import 'package:enum_to_string/enum_to_string.dart';
import 'package:mobileraker/WsHelper.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/dto/server/Klipper.dart';
import 'package:rxdart/rxdart.dart';
import 'package:simple_logger/simple_logger.dart';

/**
 * Handley Server connections/services
 */
class KlippyService {
  final _webSocket = locator<WebSocketsNotifications>();
  final logger = locator<SimpleLogger>();

  BehaviorSubject<KlipperInstance> _klipperStream;

  KlippyService() {
    _webSocket.addMethodListener((m) {
      KlipperInstance l = _getLatestKlippy();
      l.klippyState = PrinterState.ready;
      _klipperStream.add(l);
    }, "notify_klippy_ready");

    _webSocket.addMethodListener((m) {
      KlipperInstance l = _getLatestKlippy();
      l.klippyState = PrinterState.shutdown;
      _klipperStream.add(l);
    }, "notify_klippy_shutdown");

    _webSocket.addMethodListener((m) {
      KlipperInstance l = _getLatestKlippy();
      l.klippyState = PrinterState.disconnected;
      _klipperStream.add(l);
    }, "notify_klippy_disconnected");
  }

  Stream<KlipperInstance> fetchKlippy() {
    _klipperStream = BehaviorSubject<KlipperInstance>();
    _klipperStream.add(new KlipperInstance(
        klippyConnected: false, klippyState: PrinterState.startup));
    _webSocket.sendObject("server.info", _serverInfo);

    return _klipperStream.stream;
  }

  KlipperInstance _getLatestKlippy() {
    return _klipperStream.hasValue
        ? _klipperStream.value
        : new KlipperInstance();
  }

  _onStatusUpdate(Map<String, dynamic> rawMessage) {
    // Map<String, dynamic> params = rawMessage['params'][0];
    //
    // for (MapEntry<String, Function> listener in _statusUpdateListener) {
    //   if (params[listener.key] != null) listener.value(params[listener.key]);
    // }
  }

  _serverInfo(response) {
    logger.shout('ServerInfo: $response');

    PrinterState state =
        EnumToString.fromString(PrinterState.values, response['klippy_state']);
    bool con = response['klippy_connected'];
    List<String> plugins = response['plugins'].cast<String>();
    KlipperInstance klipperInstance = _getLatestKlippy();

    klipperInstance = _klipperStream.value;
    klipperInstance.klippyState = state;
    klipperInstance.plugins = plugins;
    klipperInstance.klippyConnected = con;

    _klipperStream.add(klipperInstance);
  }

  restartMCUs() {
    _webSocket.sendObject("printer.firmware_restart", null);
  }

  rebootHost() {
    _webSocket.sendObject("machine.reboot", null);
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
}
