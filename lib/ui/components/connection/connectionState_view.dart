import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/WebSocket.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';
import 'connectionState_viewmodel.dart';

class ConnectionStateView extends StatelessWidget {
  ConnectionStateView({required this.pChild, Key? key}) : super(key: key);

  final Widget pChild;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<ConnectionStateViewModel>.reactive(
      builder: (context, model, child) {
        if (model.hasPrinter)
          return checkWebsocket(context, model);
        else
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline),
                SizedBox(
                  height: 30,
                ),
                RichText(
                  text: TextSpan(
                    text: 'You will have to ',
                    style: DefaultTextStyle.of(context).style,
                    children: <TextSpan>[

                      TextSpan(
                          text: 'add',
                          style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = model.onAddPrinterTap),
                      TextSpan(
                          text: ' a printer first!',
                          ),
                    ],
                  ),
                )

              ],
            ),
          );
      },
      viewModelBuilder: () => ConnectionStateViewModel(),
    );
  }

  Widget checkWebsocket(BuildContext context, ConnectionStateViewModel model) {
    switch (model.connectionState) {
      case WebSocketState.connected:
        return pChild;

      case WebSocketState.disconnected:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_outlined),
              SizedBox(
                height: 30,
              ),
              Text("Error while trying to connect. Please retry later."),
              TextButton.icon(
                  onPressed: model.onRetryPressed,
                  icon: Icon(Icons.stream),
                  label: Text("Reconnect"))
            ],
          ),
        );
      case WebSocketState.connecting:
        return Center(
          key:UniqueKey(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitPouringHourglass(
                color: Theme.of(context).accentColor,
              ),
              SizedBox(
                height: 30,
              ),
              FadingText("Trying to connect ..."),
            ],
          ),
        );
      case WebSocketState.error:
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_outlined),
              SizedBox(
                height: 30,
              ),
              Text("Error while trying to connect. Please retry later."),
              TextButton.icon(
                  onPressed: model.onRetryPressed,
                  icon: Icon(Icons.stream),
                  label: Text("Reconnect"))
            ],
          ),
        );
    }
  }
}
