/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/machine_last_seen_service.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/overview/components/common/machine_cam_base_card.dart';

import '../../../../routing/app_router.dart';
import 'klippy_state_handler.dart';
import 'printer_card.dart';

class ConnectionStateHandler extends ConsumerWidget {
  const ConnectionStateHandler({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding ${machine.logNameExtended}/PrinterCard/ConnectionStateHandler');

    return AsyncGuard(
      debugLabel: '${machine.logNameExtended}/PrinterCard/ConnectionStateHandler',
      toGuard: jrpcClientStateProvider(machine.uuid).selectAs((d) => true),
      childOnData: _Body(machine: machine),
      childOnLoading: PrinterCard.loading(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientState = ref.watch(jrpcClientStateProvider(machine.uuid).requireValue());

    var body = switch (clientState) {
      ClientState.connected => KlippyStateHandler(machine: machine),
      ClientState.disconnected => _ClientDisconnectedBody(machine: machine), // -> Actions
      ClientState.error => _ClientErrorBody(machine: machine), // -> Actions
      ClientState.connecting => _ClientConnectingBody(machine: machine),
    };
    if (clientState != ClientState.connected) {
      return MachineCamBaseCard(machine: machine, body: body);
    }

    return body;
  }
}

class _ClientDisconnectedBody extends ConsumerWidget {
  const _ClientDisconnectedBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _ClientDisconnectedBody');
    final dateFormat = ref.watch(dateFormatServiceProvider).formatRelativeHm();
    final lastSeen = ref.watch(machineLastSeenProvider(machine.uuid))?.let(dateFormat) ?? tr('general.unknown');

    final themeData = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Gap(8),
        Icon(Icons.wifi_off, size: 36, color: themeData.disabledColor),
        Gap(4),
        Text('components.machine_card.client_state.disconnected',
                style: themeData.textTheme.titleMedium, textAlign: TextAlign.center)
            .tr(),
        Text('@:components.machine_card.last_seen: $lastSeen',
                style: themeData.textTheme.bodySmall, textAlign: TextAlign.center)
            .tr(),
        Gap(8),
        _Actions(machine: machine, clientState: ClientState.disconnected),
      ],
    );
  }
}

class _ClientErrorBody extends ConsumerWidget {
  const _ClientErrorBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = ref.watch(dateFormatServiceProvider).formatRelativeHm();
    final lastSeen = ref.watch(machineLastSeenProvider(machine.uuid))?.let(dateFormat) ?? tr('general.unknown');

    final errorMessage = ref.watch(jrpcClientProvider(machine.uuid).select((d) => d.errorReason));

    final themeData = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Gap(8),
        Icon(Icons.warning_amber, size: 36, color: themeData.colorScheme.error),
        Gap(4),
        Text('client_state.error',
                style: themeData.textTheme.titleMedium?.copyWith(color: themeData.colorScheme.error),
                textAlign: TextAlign.center)
            .tr(),
        Text('@:components.machine_card.last_seen: $lastSeen',
                style: themeData.textTheme.bodySmall, textAlign: TextAlign.center)
            .tr(),
        if (errorMessage != null) ...[
          Gap(4),
          SizedBox(
            width: double.infinity,
            child: Card(
              color: themeData.colorScheme.errorContainer,
              margin: EdgeInsets.zero,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  errorMessage.toString(),
                  style: themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.onErrorContainer),
                ),
              ),
            ),
          ),
        ],
        Gap(8),
        _Actions(machine: machine, clientState: ClientState.error),
      ],
    );
  }
}

class _ClientConnectingBody extends HookConsumerWidget {
  const _ClientConnectingBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AnimationController animationController = useAnimationController(
      duration: const Duration(seconds: 1),
    )..repeat();

    final dateFormat = ref.watch(dateFormatServiceProvider).formatRelativeHm();
    final lastSeen = ref.watch(machineLastSeenProvider(machine.uuid))?.let(dateFormat) ?? tr('general.unknown');

    var themeData = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Gap(8),
        RotationTransition(turns: animationController, child: Icon(Icons.autorenew, size: 36)),
        Gap(4),
        Text(
          'components.connection_watcher.trying_connect',
          style: themeData.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ).tr(),
        Text('@:components.machine_card.last_seen: $lastSeen',
                style: themeData.textTheme.bodySmall, textAlign: TextAlign.center)
            .tr(),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({super.key, required this.machine, required this.clientState});

  final Machine machine;

  final ClientState clientState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _KlippyActions for ${machine.logName}');

    final themeData = Theme.of(context);
    final buttons = <Widget>[];

    connect() => ref.read(jrpcClientProvider(machine.uuid)).openChannel().ignore();

    switch (clientState) {
      // Error -> Reconnect, Settings
      // disconnected -> Reconnect

      case ClientState.disconnected:
        buttons.add(ElevatedButton.icon(
          onPressed: connect,
          label: Text('components.connection_watcher.reconnect').tr(),
          icon: Icon(Icons.restart_alt),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
            iconColor: themeData.colorScheme.onPrimary,
          ),
        ));
        break;

      case ClientState.error:
        buttons.add(ElevatedButton.icon(
          onPressed: connect,
          label: Text('general.retry').tr(),
          icon: Icon(Icons.restart_alt),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
            iconColor: themeData.colorScheme.onPrimary,
          ),
        ));
        buttons.add(ElevatedButton(
          onPressed: () => ref.read(goRouterProvider).pushNamed(AppRoute.printerEdit.name, extra: machine),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.colorScheme.secondary,
            foregroundColor: themeData.colorScheme.onSecondary,
          ),
          child: Text('general.settings').tr(),
        ));
        break;
      default:
      // Do Nothing;
    }

    return Row(
      spacing: 6,
      children: [for (var button in buttons) Expanded(child: button)],
    );
  }
}
