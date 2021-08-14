import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:mobileraker/app/AppSetup.logger.dart';
import 'package:stacked/stacked.dart';

class SettingViewModel extends BaseViewModel {
  final _logger = getLogger("SettingViewModel");
  // late final WebSocketWrapper _webSocket = _machineService.webSocket;

  onUrlChanged(String address) {
    _logger.i("Add changed to: $address");
    // _webSocket.initCommunication(1);
  }

  testNotify() {
    AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: 10,
            progress: 50,
            notificationLayout: NotificationLayout.ProgressBar,
            channelKey: 'basic_channel',
            title: 'Printer Progress',
            body: 'Printing since 2h 5min ....'));
  }
}
