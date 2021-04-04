import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:mobileraker/WsHelper.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:simple_logger/simple_logger.dart';
import 'package:stacked/stacked.dart';

class SettingViewModel extends BaseViewModel {
  final _logger = locator<SimpleLogger>();
  final _webSocket = locator<WebSocketsNotifications>();

  void onUrlChanged(String address) {
    _logger.info("Add changed to: $address");
    _webSocket.initCommunication(1);
  }

  void testNotify() {
    AwesomeNotifications().createNotification(

        content: NotificationContent(
            id: 10,
            progress: 50,
            notificationLayout: NotificationLayout.ProgressBar,
            channelKey: 'basic_channel',
            title: 'Printer Progress',
            body: 'Printing since 2h 5min ....'
        )
    );
  }
}
