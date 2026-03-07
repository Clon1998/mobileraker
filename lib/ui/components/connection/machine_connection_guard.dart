/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';

import 'package:common/data/model/hive/machine.dart';
import 'package:common/exceptions/octo_everywhere_exception.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/connection/klippy_provider_guard.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/power_api_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/webcam_card.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'machine_connection_guard.g.dart';

typedef OnConnectedBuilder = Widget Function(BuildContext context, String machineUUID);

class MachineConnectionGuard extends ConsumerWidget {
  const MachineConnectionGuard({super.key, required this.onConnected, this.skipKlipperReady = false});

  // Widget to show when ws is Connected
  final OnConnectedBuilder onConnected;
  final bool skipKlipperReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machine = ref.watch(selectedMachineProvider);
    return Center(
      child: switch (machine) {
        AsyncData(value: null) => const _WelcomeMessage().also((_) => talker.info('MACHINE GUARD DETECTED NO MACHINE')),
        AsyncData(:final value?) => _WebsocketStateWidget(
          machineUUID: value.uuid,
          skipKlipperReady: skipKlipperReady,
          onConnected: onConnected,
        ),
        AsyncError(:var error) => ResponsiveLimit(
          child: ErrorCard(
            title: const Text('components.connection_watcher.error_selecting_machine').tr(),
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
    final machine = ref.watch(machineProvider(machineUUID)).requireValue;
    final themeData = Theme.of(context);

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
              klippyErrorChildren: [
                WebcamCard(machineUUID: machineUUID),
                PowerApiCard(machineUUID: machineUUID),
              ],
            );

          case ClientState.disconnected:
            return _ConnectionErrorWidget(
              machine: machine!,
              clientType: clientType,
              title: const Text('@:klipper_state.disconnected !').tr(),
              message: Text(
                'components.connection_watcher.lost_connection',
                textAlign: TextAlign.center,
              ).tr(args: [machine.name, machine.httpUri.host]),
              actionButton: OutlinedButton.icon(
                onPressed: controller.onRetryPressed,
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('components.connection_watcher.reconnect').tr(),
              ),
            );
          case ClientState.connecting:
            return ResponsiveLimit(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (clientType == ClientType.local) SpinKitPulse(size: 100, color: themeData.colorScheme.secondary),
                  if (clientType != ClientType.local)
                    SpinKitPouringHourGlassRefined(size: 100, color: themeData.colorScheme.secondary),
                  const SizedBox(height: 30),
                  FadingText(
                    tr(
                      clientType == ClientType.local
                          ? 'components.connection_watcher.trying_connect'
                          : 'components.connection_watcher.trying_connect_remote',
                    ),
                  ),
                ],
              ),
            );
          case ClientState.error:
            return _ConnectionErrorWidget(
              machine: machine!,
              clientType: clientType,
              title: const Text('components.connection_watcher.machine_not_reachable').tr(),
              message: Text(
                'components.connection_watcher.could_not_connect',
                textAlign: TextAlign.center,
              ).tr(args: [machine.name, machine.httpUri.host]),
              errorChip: ActionChip(
                onPressed: controller.onErrorDetailsPressed,
                avatar: Icon(Icons.info, color: Theme.of(context).colorScheme.onErrorContainer),
                label: Text(
                  controller.shortErrorMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                side: BorderSide.none,
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
              showEditAction: true,
              actionButton: !controller.errorIsOctoSupportedExpired
                  ? OutlinedButton.icon(
                      onPressed: controller.onRetryPressed,
                      icon: const Icon(Icons.restart_alt_outlined),
                      label: const Text('components.connection_watcher.reconnect').tr(),
                    )
                  : TextButton.icon(
                      onPressed: controller.onGoToOE,
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('components.connection_watcher.more_details').tr(),
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

class _ConnectionErrorWidget extends StatelessWidget {
  const _ConnectionErrorWidget({
    super.key,
    required this.machine,
    required this.clientType,
    required this.title,
    required this.message,
    required this.actionButton,
    this.errorChip,
    this.showEditAction = false,
  });

  final Machine machine;
  final ClientType clientType;
  final Widget title;
  final Widget message;
  final Widget? errorChip;
  final Widget actionButton;
  final bool showEditAction;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return ResponsiveLimit(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: 0.2,
                      child: SvgPicture.asset('assets/vector/undraw_connection-lost_am29.svg'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DefaultTextStyle(style: themeData.textTheme.headlineSmall ?? const TextStyle(), child: title),
                  message,
                  Gap(8),
                  ?errorChip,
                  actionButton,
                  if (showEditAction)
                    TextButton.icon(
                      onPressed: () => context.pushNamed(AppRoute.printerEdit.name, extra: machine),
                      icon: const Icon(Icons.edit),
                      label: const Text('components.connection_watcher.edit_machine_settings').tr(),
                    ),
                ],
              ),
            ),
            if (clientType == ClientType.octo || clientType == ClientType.obico)
              Text(
                'bottom_sheets.add_remote_con.disclosure',
                textAlign: TextAlign.center,
                style: themeData.textTheme.bodySmall,
              ).tr(namedArgs: {'service': (clientType == ClientType.octo) ? 'OctoEverywhere' : 'Obico'}),
          ],
        ),
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

  void onErrorDetailsPressed() {
    final dialogService = ref.read(dialogServiceProvider);

    dialogService.show(
      DialogRequest(
        type: CommonDialogs.stacktrace,
        title: tr('components.connection_watcher.connection_error_details'),
        body: clientErrorMessage,
      ),
    );
  }

  @override
  bool updateShouldNotify(AsyncValue<(ClientState, ClientType)> previous, AsyncValue<(ClientState, ClientType)> next) {
    return previous != next;
  }

  String get clientErrorMessage {
    var jsonRpcClient = ref.read(jrpcClientProvider(machineUUID));
    Object? errorReason = jsonRpcClient.errorReason;
    if (errorReason is TimeoutException) {
      return tr('components.connection_watcher.timeout_error');
    } else if (errorReason is OctoEverywhereException) {
      return tr('components.connection_watcher.octoeverywhere_returned', args: [errorReason.message]);
    } else if (errorReason != null) {
      return errorReason.toString();
    }
    return tr('components.connection_watcher.general_connection_error');
  }

  String get shortErrorMessage {
    var jsonRpcClient = ref.read(jrpcClientProvider(machineUUID));
    Object? errorReason = jsonRpcClient.errorReason;
    if (errorReason is TimeoutException) {
      return tr('components.connection_watcher.connection_timeout');
    } else if (errorReason is OctoEverywhereException) {
      return tr('components.connection_watcher.octoeverywhere_error', args: [errorReason.message]);
    } else if (errorReason is SocketException) {
      final serr = errorReason as SocketException;
      return 'error ${serr.osError?.errorCode} · ${serr.message}';
    }
    return tr('components.connection_watcher.unknown_error');
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
    var oeURI = Uri.parse('https://octoeverywhere.com/appportal/v1/nosupporterperks?moonraker=true&appid=mobileraker');
    if (await canLaunchUrl(oeURI)) {
      await launchUrl(oeURI, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $oeURI';
    }
  }
}
