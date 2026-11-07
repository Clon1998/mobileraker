/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/connection/client_type_indicator.dart';

class MachineStateIndicator extends ConsumerWidget {
  const MachineStateIndicator(this.machine, {super.key});
  final Machine? machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    KlipperInstance? klippyData;
    ClientState? clientState;
    if (machine != null) {
      var machineUUID = machine!.uuid;
      klippyData = ref.watch(klipperProvider(machineUUID)).value;
      clientState = ref.watch(jrpcClientStateProvider(machineUUID)).value;
    }
    clientState ??= ClientState.disconnected;

    KlipperState serverState = klippyData?.klippyState ?? KlipperState.disconnected;

    switch (clientState) {
      case ClientState.connected:
        var klippyStateToColor = _klippyStateToColor(context, serverState);
        return Tooltip(
          padding: const EdgeInsets.all(8.0),
          message: 'pages.dashboard.server_status'.tr(
            args: [
              serverState.displayName.tr(),
              klippyData?.klippyConnected ?? false
                  ? tr('general.connected').toLowerCase()
                  : tr('klipper_state.disconnected').toLowerCase(),
            ],
            gender: 'available',
          ),
          child: MachineActiveClientTypeIndicator(
            machineId: machine?.uuid,
            iconSize: 20,
            iconColor: klippyStateToColor,
            localIndicator: Icon(
              Icons.radio_button_on,
              size: 10,
              color: klippyStateToColor,
            ),
          ),
        );
      default:
        return Icon(
          Icons.radio_button_on,
          size: 10,
          color: _stateToColor(context, clientState),
        );
    }
  }

  Color _klippyStateToColor(BuildContext context, KlipperState state) {
    CustomColors? customColors = Theme.of(context).extension<CustomColors>();

    switch (state) {
      case KlipperState.ready:
        return customColors?.success ?? Colors.green;
      case KlipperState.error:
        return customColors?.danger ?? Colors.red;
      case KlipperState.startup:
        return customColors?.info ?? Colors.blueAccent;
      case KlipperState.shutdown:
      case KlipperState.disconnected:
      default:
        return customColors?.warning ?? Colors.orange;
    }
  }

  Color _stateToColor(BuildContext context, ClientState state) {
    CustomColors? customColors = Theme.of(context).extension<CustomColors>();

    switch (state) {
      case ClientState.connected:
        return customColors?.success ?? Colors.green;
      case ClientState.error:
        return customColors?.danger ?? Colors.red;
      case ClientState.connecting:
        return customColors?.info ?? Colors.blueAccent;
      case ClientState.disconnected:
      default:
        return customColors?.warning ?? Colors.orange;
    }
  }
}

/// Single-line status text of a machine for subtitles, e.g. the app bar: the connection, Klipper or print state.
/// Remote connections append their client type icon; the tooltip has the Klipper details.
class MachineStatusLabel extends ConsumerWidget {
  const MachineStatusLabel(this.machine, {super.key, this.style});

  final Machine machine;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machineUUID = machine.uuid;
    final clientState = ref.watch(jrpcClientStateProvider(machineUUID)).value ?? ClientState.disconnected;
    final (klippyState, klippyConnected) = ref.watch(
      klipperProvider(machineUUID).select((d) => (d.value?.klippyState, d.value?.klippyConnected ?? false)),
    );
    final (printState, progress) = ref.watch(
      printerProvider(machineUUID).select((d) => (d.value?.print.state, ((d.value?.printProgress ?? 0) * 100).floor())),
    );

    final String label = switch (clientState) {
      // Connection to Moonraker (JRPC)
      ClientState.disconnected => tr('client_state.disconnected'),
      ClientState.connecting => tr('client_state.connecting'),
      ClientState.error => tr('components.machine_status.connection_error'),
      // Moonraker is reachable, now Klipper
      ClientState.connected => switch ((klippyState, klippyConnected)) {
        (null, _) => tr('client_state.connecting'),
        (KlipperState.ready, false) ||
        (KlipperState.disconnected, _) => tr('components.machine_status.klipper_disconnected'),
        (KlipperState.error, _) => tr('components.machine_status.klipper_error'),
        (KlipperState.shutdown, _) => tr('components.machine_status.klipper_shutdown'),
        (KlipperState state, _) when state != KlipperState.ready => tr(state.displayName),
        // Klipper is ready, now the print
        _ => switch (printState) {
          null => tr(KlipperState.ready.displayName),
          PrintState.printing || PrintState.paused => '${printState.displayName} $progress%',
          PrintState state => state.displayName,
        },
      },
    };

    final tooltip = clientState == ClientState.connected
        ? 'pages.dashboard.server_status'.tr(
            args: [
              tr((klippyState ?? KlipperState.disconnected).displayName),
              klippyConnected ? tr('general.connected').toLowerCase() : tr('klipper_state.disconnected').toLowerCase(),
            ],
            gender: 'available',
          )
        : label;

    final textStyle = style ?? DefaultTextStyle.of(context).style;

    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(label, style: textStyle, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
          ),
          // Only remote connections get an icon, like the old indicator
          if (clientState == ClientState.connected)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: MachineActiveClientTypeIndicator(
                machineId: machineUUID,
                iconSize: (textStyle.fontSize ?? 12) + 2,
                iconColor: textStyle.color,
              ),
            ),
        ],
      ),
    );
  }
}
