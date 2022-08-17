import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/connection/connection_state_controller.dart';
import 'package:progress_indicators/progress_indicators.dart';

class ConnectionStateView extends ConsumerWidget {
  const ConnectionStateView({Key? key, required this.onConnected})
      : super(key: key);

  // Widget to show when ws is Connected
  final Widget onConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(selectedMachineProvider);
    if (machine.isRefreshing) {
      return const Center(child: CircularProgressIndicator());
    }

    return machine.valueOrNull != null
        ? WebSocketState(
            onConnected: onConnected,
          )
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(
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
                            ..onTap = () {
                              ref
                                  .read(goRouterProvider)
                                  .pushNamed(AppRoute.printerAdd.name);
                            }),
                      const TextSpan(
                        text: ' a printer first!',
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
  }
}

class WebSocketState extends HookConsumerWidget {
  const WebSocketState({Key? key, required this.onConnected}) : super(key: key);
  final Widget onConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ClientState connectionState = ref.watch(connectionStateControllerProvider);
    useOnAppLifecycleStateChange(ref
        .watch(connectionStateControllerProvider.notifier)
        .onChangeAppLifecycleState);
    switch (connectionState) {
      case ClientState.connected:
        return KlippyState(
          onConnected: onConnected,
        );

      case ClientState.disconnected:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_outlined,
                  size: 50, color: Theme.of(context).colorScheme.error),
              const SizedBox(
                height: 30,
              ),
              const Text('@:klipper_state.disconnected !').tr(),
              TextButton.icon(
                  onPressed: ref
                      .read(connectionStateControllerProvider.notifier)
                      .onRetryPressed,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('components.connection_watcher.reconnect')
                      .tr())
            ],
          ),
        );
      case ClientState.connecting:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitPulse(
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(
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
              Icon(
                Icons.warning_amber_outlined,
                size: 50,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                ref
                    .read(connectionStateControllerProvider.notifier)
                    .clientErrorMessage,
                textAlign: TextAlign.center,
              ),
              TextButton.icon(
                  onPressed: ref
                      .read(connectionStateControllerProvider.notifier)
                      .onRetryPressed,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('components.connection_watcher.reconnect')
                      .tr())
            ],
          ),
        );
    }
  }
}

class KlippyState extends ConsumerWidget {
  const KlippyState({Key? key, required this.onConnected}) : super(key: key);
  final Widget onConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(printerSelectedProvider.select((value) => value.hasValue))) {
      return onConnected;
    }

    return AsyncValueWidget<KlipperInstance>(
      value: ref.watch(klipperSelectedProvider),
      data: (data) {
        switch (data.klippyState) {
          case KlipperState.disconnected:
          case KlipperState.shutdown:
          case KlipperState.error:
            return Center(
              child: Column(
                children: [
                  const Spacer(),
                  Card(
                      child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            FlutterIcons.disconnect_ant,
                          ),
                          title: Text(data.klippyState.name).tr(),
                        ),
                        Text(
                            data.klippyStateMessage ??
                                tr(data.klippyState.name),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: ref
                                  .read(connectionStateControllerProvider
                                      .notifier)
                                  .onRestartKlipperPressed,
                              child: const Text(
                                      'pages.dashboard.general.restart_klipper')
                                  .tr(),
                            ),
                            ElevatedButton(
                              onPressed: ref
                                  .read(connectionStateControllerProvider
                                      .notifier)
                                  .onRestartMCUPressed,
                              child: const Text(
                                      'pages.dashboard.general.restart_mcu')
                                  .tr(),
                            )
                          ],
                        )
                      ],
                    ),
                  )),
                  const Spacer()
                ],
              ),
            );
          case KlipperState.startup:
            return Center(
              child: Column(
                children: [
                  const Spacer(),
                  Card(
                      child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            FlutterIcons.disconnect_ant,
                          ),
                          title: Text(data.klippyState.name).tr(),
                        ),
                        const Text(
                                'components.connection_watcher.server_starting')
                            .tr()
                      ],
                    ),
                  )),
                  const Spacer()
                ],
              ),
            );
          case KlipperState.ready:
          default:
            return onConnected;
        }
      },
    );
  }
}
