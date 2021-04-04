import 'package:stacked/stacked.dart';
import 'package:mobileraker/WsHelper.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:stacked_services/stacked_services.dart';

class ConnectionStateViewModel extends StreamViewModel<WebSocketState> {
  final _webSocket = locator<WebSocketsNotifications>();
  final _snackBarService = locator<SnackbarService>();

  @override
  void onData(WebSocketState data) {
    super.onData(data);
    switch (data) {
      case WebSocketState.disconnected:
        // TODO: Handle this case.
        break;
      case WebSocketState.connecting:
        // _snackBarService.showSnackbar(
        //     message: "Trying to connect to Moonraker. Retry: ${_webSocket.retries}");
        break;
      case WebSocketState.connected:
        _snackBarService.showSnackbar(message: "Connected to Moonraker");
        break;
      case WebSocketState.error:
        _snackBarService.showSnackbar(
            message:
                "Error while trying to connect: ${_webSocket.lastError}");
        break;
    }
  }

  onRetryPressed() {
    _webSocket.initCommunication();
  }

  @override
  // TODO: implement stream
  Stream<WebSocketState> get stream => _webSocket.stateStream;

  WebSocketState get connectionState => data;
  int get retryCount => _webSocket.retries;
}
