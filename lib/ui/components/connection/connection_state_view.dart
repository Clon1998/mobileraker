import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/datasource/websocket_wrapper.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

import 'connection_state_viewmodel.dart';

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
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline),
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
              Text("Disconnected!"),
              TextButton.icon(
                  onPressed: model.onRetryPressed,
                  icon: Icon(Icons.stream),
                  label: Text("Reconnect"))
            ],
          ),
        );
      case WebSocketState.connecting:
        return Center(
          key: UniqueKey(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitPouringHourGlassRefined(
                color: Theme.of(context).colorScheme.secondary,
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
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_outlined),
              SizedBox(
                height: 20,
              ),
              Text(
                model.websocketErrorMessage,
                textAlign: TextAlign.center,
              ),
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
