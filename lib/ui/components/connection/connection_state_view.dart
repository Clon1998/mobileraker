import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/datasource/websocket_wrapper.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

import 'connection_state_viewmodel.dart';

class ConnectionStateView
    extends ViewModelBuilderWidget<ConnectionStateViewModel> {
  ConnectionStateView({required this.pChild, Key? key}) : super(key: key);

  final Widget pChild;

  Widget widgetForWebsocketState(
      BuildContext context, ConnectionStateViewModel model) {
    switch (model.connectionState) {
      case WebSocketState.connected:
        return widgetForKlippyServerState(context, model);

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

  Widget widgetForKlippyServerState(
      BuildContext context, ConnectionStateViewModel model) {
    if (model.isPrinterAvailable) return pChild;
    switch (model.server.klippyState) {
      case KlipperState.disconnected:
      case KlipperState.shutdown:
      case KlipperState.error:
        return Center(
          child: Column(
            children: [
              Spacer(),
              Card(
                  child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        FlutterIcons.disconnect_ant,
                      ),
                      title: Text(model.klippyState),
                    ),
                    Text(model.errorMessage,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: model.onRestartKlipperPressed,
                          child: Text('pages.overview.general.restart_klipper').tr(),
                        ),
                        ElevatedButton(
                          onPressed: model.onRestartMCUPressed,
                          child: Text('pages.overview.general.restart_mcu').tr(),
                        )
                      ],
                    )
                  ],
                ),
              )),
              Spacer()
            ],
          ),
        );
        case KlipperState.startup:
        return Center(
          child: Column(
            children: [
              Spacer(),
              Card(
                  child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        FlutterIcons.disconnect_ant,
                      ),
                      title: Text(model.klippyState),
                    ),
                    Text('Server is starting.')
                  ],
                ),
              )),
              Spacer()
            ],
          ),
        );
      case KlipperState.ready:
      default:
        return pChild;
    }
  }

  @override
  Widget builder(
      BuildContext context, ConnectionStateViewModel model, Widget? child) {
    return model.isMachineAvailable
        ? widgetForWebsocketState(context, model)
        : Center(
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
  }

  @override
  ConnectionStateViewModel viewModelBuilder(BuildContext context) =>
      ConnectionStateViewModel();
}
