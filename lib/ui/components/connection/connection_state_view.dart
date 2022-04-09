import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/datasource/json_rpc_client.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

import 'connection_state_viewmodel.dart';

class ConnectionStateView
    extends ViewModelBuilderWidget<ConnectionStateViewModel> {

  @override
  bool get disposeViewModel => false;

  @override
  bool get initialiseSpecialViewModelsOnce => true;

  // Widget to show when ws is Connected
  final Widget body;

  ConnectionStateView({Key? key, required this.body})
      : super(key: key);

  @override
  Widget builder(
      BuildContext context, ConnectionStateViewModel model, Widget? child) {
    return model.isMachineAvailable
        ? _widgetForWebsocketState(context, model)
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

  Widget _widgetForWebsocketState(
      BuildContext context, ConnectionStateViewModel model) {
    switch (model.connectionState) {
      case ClientState.connected:
        return _widgetForKlippyServerState(context, model);

      case ClientState.disconnected:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_outlined),
              SizedBox(
                height: 30,
              ),
              Text('@:klipper_state.disconnected !').tr(),
              TextButton.icon(
                  onPressed: model.onRetryPressed,
                  icon: Icon(Icons.restart_alt_outlined),
                  label: Text('components.connection_watcher.reconnect').tr())
            ],
          ),
        );
      case ClientState.connecting:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitPulse(
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(
                height: 30,
              ),
              FadingText(tr('components.connection_watcher.trying_connect')),
            ],
          ),
        );
      case ClientState.error:
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
                model.clientErrorMessage,
                textAlign: TextAlign.center,
              ),
              TextButton.icon(
                  onPressed: model.onRetryPressed,
                  icon: Icon(Icons.restart_alt_outlined),
                  label: Text('components.connection_watcher.reconnect').tr())
            ],
          ),
        );
    }
  }

  Widget _widgetForKlippyServerState(
      BuildContext context, ConnectionStateViewModel model) {
    if (model.isPrinterAvailable) return body;
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
                          child: Text('pages.dashboard.general.restart_klipper')
                              .tr(),
                        ),
                        ElevatedButton(
                          onPressed: model.onRestartMCUPressed,
                          child:
                              Text('pages.dashboard.general.restart_mcu').tr(),
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
                    Text('components.connection_watcher.server_starting').tr()
                  ],
                ),
              )),
              Spacer()
            ],
          ),
        );
      case KlipperState.ready:
      default:
        return body;
    }
  }

  @override
  ConnectionStateViewModel viewModelBuilder(BuildContext context) =>
      locator<ConnectionStateViewModel>();
}
