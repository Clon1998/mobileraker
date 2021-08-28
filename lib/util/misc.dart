import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:stacked_services/stacked_services.dart';

void showWIPSnackbar() {
  locator<SnackbarService>().showSnackbar(
      title: 'Dev-Message', message: "WIP!... Not implemented yet.");
}

String urlToWebsocketUrl(String enteredURL) {
  
  var parse = Uri.tryParse(enteredURL);
  if (parse == null) return enteredURL;
  if (!parse.hasScheme)
    parse = Uri.tryParse('ws://$enteredURL/websocket');
  else if (parse.isScheme('http'))
    parse = parse.replace(scheme: 'ws');
  else if (parse.isScheme('https')) parse = parse.replace(scheme: 'wss');

  return parse.toString();

  // var parse = Uri.tryParse(enteredURL);
  //
  // return (parse?.hasScheme ?? false)
  //     ? enteredURL
  //     : 'ws://$enteredURL/websocket';
}
