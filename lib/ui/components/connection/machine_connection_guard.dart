/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/exceptions/octo_everywhere_exception.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/ui/components/connection/klippy_provider_guard.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/power_api_card.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'machine_connection_guard.g.dart';

typedef OnConnectedBuilder = Widget Function(BuildContext context, String machineUUID);

class MachineConnectionGuard extends ConsumerWidget {
  const MachineConnectionGuard({
    super.key,
    required this.onConnected,
    this.skipKlipperReady = false,
  });

  // Widget to show when ws is Connected
  final OnConnectedBuilder onConnected;
  final bool skipKlipperReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machine = ref.watch(selectedMachineProvider);
    return Center(
      child: switch (machine) {
        AsyncData(value: null) => const _WelcomeMessage().also((_) => logger.i('MACHINE GUARD DETECTED NO MACHINE')),
        AsyncData(:final value?) => _WebsocketStateWidget(
            machineUUID: value.uuid,
            skipKlipperReady: skipKlipperReady,
            onConnected: onConnected,
          ),
        AsyncError(:var error) => ResponsiveLimit(
            child: ErrorCard(
              title: const Text('Error selecting active machine'),
              body: Text(error.toString()),
            ),
          ),
        _ => const CircularProgressIndicator.adaptive(),
      },
    );
  }
}

class _WebsocketStateWidget extends ConsumerWidget {
  const _WebsocketStateWidget({
    super.key,
    required this.machineUUID,
    required this.onConnected,
    this.skipKlipperReady = false,
  });

  final String machineUUID;

  final OnConnectedBuilder onConnected;

  final bool skipKlipperReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_machineConnectionGuardControllerProvider(machineUUID));
    final controller = ref.watch(_machineConnectionGuardControllerProvider(machineUUID).notifier);

    return AsyncValueWidget(
      // Warum brauche ich den key?
      // key: ValueKey(model),
      value: model,
      data: (data) {
        final (clientState, clientType) = data;

        switch (clientState) {
          case ClientState.connected:
            return KlippyProviderGuard(
              machineUUID: machineUUID,
              onConnected: onConnected,
              skipKlipperReady: skipKlipperReady,
              klippyErrorChildren: [PowerApiCard(machineUUID: machineUUID)],
            );

          case ClientState.disconnected:
            return ResponsiveLimit(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 50,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 30),
                  const Text('@:klipper_state.disconnected !').tr(),
                  TextButton.icon(
                    onPressed: controller.onRetryPressed,
                    icon: const Icon(Icons.restart_alt_outlined),
                    label: const Text('components.connection_watcher.reconnect').tr(),
                  ),
                ],
              ),
            );
          case ClientState.connecting:
            return ResponsiveLimit(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (clientType == ClientType.local)
                    SpinKitPulse(
                      size: 100,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  if (clientType != ClientType.local)
                    SpinKitPouringHourGlassRefined(
                      size: 100,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  const SizedBox(height: 30),
                  FadingText(tr(clientType == ClientType.local
                      ? 'components.connection_watcher.trying_connect'
                      : 'components.connection_watcher.trying_connect_remote')),
                ],
              ),
            );
          case ClientState.error:
          default:
            return ResponsiveLimit(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            size: 50,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            controller.clientErrorMessage,
                            textAlign: TextAlign.center,
                          ),
                          if (!controller.errorIsOctoSupportedExpired)
                            TextButton.icon(
                              onPressed: controller.onRetryPressed,
                              icon: const Icon(Icons.restart_alt_outlined),
                              label: const Text(
                                'components.connection_watcher.reconnect',
                              ).tr(),
                            ),
                          if (controller.errorIsOctoSupportedExpired)
                            TextButton.icon(
                              onPressed: controller.onGoToOE,
                              icon: const Icon(Icons.open_in_browser),
                              label: const Text(
                                'components.connection_watcher.more_details',
                              ).tr(),
                            ),
                        ],
                      ),
                    ),
                    if (clientType == ClientType.octo || clientType == ClientType.obico)
                      Text(
                        'bottom_sheets.add_remote_con.disclosure',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ).tr(namedArgs: {'service': (clientType == ClientType.octo) ? 'OctoEverywhere' : 'Obico'}),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}

class _WelcomeMessage extends StatelessWidget {
  const _WelcomeMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLimit(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        // mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FractionallySizedBox(
              heightFactor: 0.5,
              child: SvgPicture.asset(
                'assets/vector/undraw_hello_re_3evm.svg',
                // fit: BoxFit.fitHeight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, top: 8),
            child: Text(
              'components.connection_watcher.add_printer',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ).tr(),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.pushNamed(AppRoute.printerAdd.name),
            icon: const Icon(Icons.add),
            label: const Text('pages.overview.add_machine').tr(),
          ),
          // const Spacer(),
        ],
      ),
    );
  }
}

@riverpod
class _MachineConnectionGuardController extends _$MachineConnectionGuardController {
  @override
  Future<(ClientState, ClientType)> build(String machineUUID) async {
    final clientType = ref.watch(jrpcClientTypeProvider(machineUUID));
    final cState = await ref.watch(jrpcClientStateProvider(machineUUID).future);

    return (cState, clientType);
  }

  void onRetryPressed() {
    ref.read(jrpcClientProvider(machineUUID)).openChannel();
  }

  @override
  bool updateShouldNotify(AsyncValue<(ClientState, ClientType)> previous, AsyncValue<(ClientState, ClientType)> next) {
    return previous != next;
  }

  String get clientErrorMessage {
    var jsonRpcClient = ref.read(jrpcClientProvider(machineUUID));
    Object? errorReason = jsonRpcClient.errorReason;
    if (errorReason is TimeoutException) {
      return 'A timeout occurred while trying to connect to the machine! Ensure the machine can be reached from your current network...';
    } else if (errorReason is OctoEverywhereException) {
      return 'OctoEverywhere returned: ${errorReason.message}';
    } else if (errorReason != null) {
      return errorReason.toString();
    }
    return 'Error while trying to connect. Please retry later.';
  }

  bool get errorIsOctoSupportedExpired {
    var jsonRpcClient = ref.read(jrpcClientProvider(machineUUID));
    Object? errorReason = jsonRpcClient.errorReason;
    if (errorReason is! OctoEverywhereHttpException) {
      return false;
    }

    return errorReason.statusCode == 605;
  }

  void onGoToOE() async {
    var oeURI = Uri.parse(
      'https://octoeverywhere.com/appportal/v1/nosupporterperks?moonraker=true&appid=mobileraker',
    );
    if (await canLaunchUrl(oeURI)) {
      await launchUrl(oeURI, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $oeURI';
    }
  }
}
