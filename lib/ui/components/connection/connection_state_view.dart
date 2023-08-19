/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/connection/connection_state_controller.dart';
import 'package:mobileraker/ui/components/error_card.dart';
import 'package:mobileraker/ui/components/power_api_panel.dart';
import 'package:progress_indicators/progress_indicators.dart';

class ConnectionStateView extends ConsumerWidget {
  const ConnectionStateView({
    Key? key,
    required this.onConnected,
    this.skipKlipperReady = false,
  }) : super(key: key);

  // Widget to show when ws is Connected
  final Widget onConnected;
  final bool skipKlipperReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(selectedMachineProvider);

    return machine.when(
        data: (machine) {
          return machine != null
              ? WebSocketState(
                  onConnected: onConnected,
                  skipKlipperReady: skipKlipperReady,
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: SvgPicture.asset('assets/vector/undraw_hello_re_3evm.svg')),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Text(
                            'components.connection_watcher.add_printer',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ).tr(),
                        ),
                        FilledButton.tonalIcon(
                            onPressed: () =>
                                ref.read(goRouterProvider).pushNamed(AppRoute.printerAdd.name),
                            icon: const Icon(Icons.add),
                            label: const Text('pages.overview.add_machine').tr()),
                        const Spacer(),
                      ],
                    ),
                  ),
                );
        },
        error: (e, _) => ErrorCard(
              title: const Text('Error selecting active machine'),
              body: Text(e.toString()),
            ),
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        skipLoadingOnRefresh: false);
  }
}

class WebSocketState extends HookConsumerWidget {
  const WebSocketState({
    Key? key,
    required this.onConnected,
    this.skipKlipperReady = false,
  }) : super(key: key);
  final Widget onConnected;

  final bool skipKlipperReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<ClientState> connectionState = ref.watch(connectionStateControllerProvider);
    ClientType clientType =
        ref.watch(jrpcClientSelectedProvider.select((value) => value.clientType));

    var connectionStateController = ref.read(connectionStateControllerProvider.notifier);
    useOnAppLifecycleStateChange(connectionStateController.onChangeAppLifecycleState);

    return AsyncValueWidget(
      value: connectionState,
      data: (ClientState clientState) {
        switch (clientState) {
          case ClientState.connected:
            return KlippyState(
              onConnected: onConnected,
              skipKlipperReady: skipKlipperReady,
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
                      onPressed: connectionStateController.onRetryPressed,
                      icon: const Icon(Icons.restart_alt_outlined),
                      label: const Text('components.connection_watcher.reconnect').tr())
                ],
              ),
            );
          case ClientState.connecting:
            return Center(
              key: ValueKey(clientType),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (clientType == ClientType.local)
                    SpinKitPulse(
                      size: 100,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  if (clientType == ClientType.octo)
                    SpinKitPouringHourGlassRefined(
                      size: 100,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  const SizedBox(
                    height: 30,
                  ),
                  FadingText(tr(clientType == ClientType.local
                      ? 'components.connection_watcher.trying_connect'
                      : 'components.connection_watcher.trying_connect_remote')),
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
                    connectionStateController.clientErrorMessage,
                    textAlign: TextAlign.center,
                  ),
                  if (!connectionStateController.errorIsOctoSupportedExpired)
                    TextButton.icon(
                        onPressed: connectionStateController.onRetryPressed,
                        icon: const Icon(Icons.restart_alt_outlined),
                        label: const Text('components.connection_watcher.reconnect').tr()),
                  if (connectionStateController.errorIsOctoSupportedExpired)
                    TextButton.icon(
                        onPressed: connectionStateController.onGoToOE,
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('components.connection_watcher.more_details').tr()),
                ],
              ),
            );
        }
      },
    );
  }
}

class KlippyState extends ConsumerWidget {
  const KlippyState({
    Key? key,
    required this.onConnected,
    this.skipKlipperReady = false,
  }) : super(key: key);
  final Widget onConnected;
  final bool skipKlipperReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (skipKlipperReady) {
      return onConnected;
    }
    if (ref.watch(printerSelectedProvider.select((value) => value.hasValue && !value.isLoading))) {
      return onConnected;
    }

    var watch = ref.watch(klipperSelectedProvider);
    return AsyncValueWidget<KlipperInstance>(
      value: watch,
      data: (data) {
        var themeData = Theme.of(context);
        switch (data.klippyState) {
          case KlipperState.disconnected:
          case KlipperState.shutdown:
          case KlipperState.error:
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            FlutterIcons.disconnect_ant,
                          ),
                          title: Text(data.klippyState.name).tr(),
                        ),
                        Text(data.klippyStateMessage ?? tr(data.klippyState.name),
                            style: TextStyle(color: themeData.colorScheme.error)),
                        ElevatedButtonTheme(
                          data: ElevatedButtonThemeData(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: themeData.colorScheme.error,
                                  foregroundColor: themeData.colorScheme.onError)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: ref
                                    .read(connectionStateControllerProvider.notifier)
                                    .onRestartKlipperPressed,
                                child: const Text('pages.dashboard.general.restart_klipper').tr(),
                              ),
                              ElevatedButton(
                                onPressed: ref
                                    .read(connectionStateControllerProvider.notifier)
                                    .onRestartMCUPressed,
                                child: const Text('pages.dashboard.general.restart_mcu').tr(),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  )),
                  if (data.components.contains('power')) const PowerApiCard(),
                ],
              ),
            );
          case KlipperState.startup:
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            FlutterIcons.disconnect_ant,
                          ),
                          title: Text(data.klippyState.name).tr(),
                        ),
                        const Text('components.connection_watcher.server_starting').tr()
                      ],
                    ),
                  )),
                ],
              ),
            );
          case KlipperState.unauthorized:
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.gpp_bad,
                    size: 70,
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  const Text(
                    'It seems like you configured trusted clients for Moonraker. Please add the API key in the printers settings!\n',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                      onPressed: ref.read(connectionStateControllerProvider.notifier).onEditPrinter,
                      child: Text('components.nav_drawer.printer_settings'.tr()))
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
