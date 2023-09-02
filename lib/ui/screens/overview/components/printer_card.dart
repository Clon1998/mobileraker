/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/components/webcam/webcam.dart';
import 'package:mobileraker/ui/screens/overview/components/printer_card_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:progress_indicators/progress_indicators.dart';

class SinglePrinterCard extends ConsumerWidget {
  const SinglePrinterCard(
    this._machine, {
    Key? key,
  }) : super(key: key);

  final Machine _machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [printerCardMachineProvider.overrideWithValue(_machine), printerCardControllerProvider],
      child: const _PrinterCard(),
    );
  }
}

class _PrinterCard extends ConsumerWidget {
  const _PrinterCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var singlePrinterCardController = ref.watch(printerCardControllerProvider.notifier);
    var machine = ref.watch(printerCardMachineProvider);
    return Card(
      child: Column(
        children: [
          const _Cam(),
          ListTile(
            onTap: singlePrinterCardController.onTapTile,
            onLongPress: singlePrinterCardController.onLongPressTile,
            title: Text(machine.name),
            subtitle: Text(machine.httpUri.toString()),
            trailing: const _Trailing(),
          )
        ],
      ),
    );
  }
}

class _Trailing extends ConsumerWidget {
  const _Trailing({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(printerCardMachineProvider);

    return ref.watch(jrpcClientStateProvider(machine.uuid)).when(
        data: (d) {
          if (d != ClientState.connected) {
            return Icon(
              FlutterIcons.disconnect_ant,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            );
          }
          return MachineStateIndicator(machine);
        },
        error: (e, s) => Tooltip(
              message: e.toString(),
              child: Icon(
                FlutterIcons.disconnect_ant,
                size: 20,
                color: Theme.of(context).errorColor,
              ),
            ),
        loading: () => FadingText('...'));
  }
}

class _PrintProgressBar extends ConsumerWidget {
  const _PrintProgressBar({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(printerCardMachineProvider);

    return Positioned.fill(
      child: Align(
          alignment: Alignment.bottomCenter,
          child: LinearProgressIndicator(
            value: ref.watch(printerProvider(machine.uuid).selectAs((data) => data.printProgress)).valueOrFullNull ?? 0,
          )),
    );
  }
}

class _Cam extends ConsumerWidget {
  const _Cam({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(printerCardMachineProvider);
    var printState = ref.watch(printerProvider(machine.uuid).selectAs((d) => d.print.state)).valueOrFullNull;

    WebcamInfo? webcamInfo = ref.watch(printerCardControllerProvider).valueOrFullNull;

    return AnimatedSwitcher(
      switchInCurve: Curves.easeInOutBack,
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(
            opacity: anim,
            child: child,
          )),
      child: (webcamInfo == null)
          ? const SizedBox.shrink()
          : Center(
              child: Webcam(
                key: ValueKey(machine.uuid + webcamInfo.uuid),
                webcamInfo: webcamInfo,
                machine: machine,
                showRemoteIndicator: false,
                stackContent: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: IconButton(
                        color: Colors.white,
                        icon: const Icon(Icons.aspect_ratio),
                        tooltip: tr('pages.dashboard.general.cam_card.fullscreen'),
                        onPressed: ref.read(printerCardControllerProvider.notifier).onFullScreenTap,
                      ),
                    ),
                  ),
                  if (printState == PrintState.printing) const _PrintProgressBar()
                ],
              ),
            ),
    );
  }

  Widget _imageBuilder(BuildContext context, Widget imageTransformed) {
    return ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(5)), child: imageTransformed);
  }
}
