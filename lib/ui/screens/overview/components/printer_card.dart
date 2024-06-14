/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/webcam/webcam.dart';
import 'package:mobileraker/ui/screens/overview/components/printer_card_controller.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:progress_indicators/progress_indicators.dart';

import '../../../components/machine_state_indicator.dart';

class SinglePrinterCard extends HookConsumerWidget {
  const SinglePrinterCard(this._machine, {super.key});

  final Machine _machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    return ProviderScope(
      overrides: [
        printerCardMachineProvider.overrideWithValue(_machine),
        printerCardControllerProvider,
      ],
      child: const _PrinterCard(),
    );
  }
}

class _PrinterCard extends ConsumerWidget {
  const _PrinterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var singlePrinterCardController = ref.watch(printerCardControllerProvider.notifier);
    var machine = ref.watch(printerCardMachineProvider);
    var themeData = Theme.of(context);
    return Card(
      child: Column(
        children: [
          const _Cam(),
          InkWell(
            onTap: singlePrinterCardController.onTapTile,
            onLongPress: singlePrinterCardController.onLongPressTile,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(machine.name, style: themeData.textTheme.titleMedium),
                      Text(
                        machine.httpUri.toString(),
                        style: themeData.textTheme.bodySmall,
                      ),
                      Consumer(builder: (context, ref, child) {
                        var printer = ref.watch(printerProvider(machine.uuid).selectAs((data) => data.print.state));

                        return switch (printer) {
                          AsyncData(value: var state) => Text(state.displayName, style: themeData.textTheme.bodySmall),
                          _ => const SizedBox.shrink(),
                        };
                      }),
                    ],
                  ),
                  const _Trailing(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Trailing extends HookConsumerWidget {
  const _Trailing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var triedReconnect = useState(false);

    var machine = ref.watch(printerCardMachineProvider);
    var jrpcClientState = ref.watch(jrpcClientStateProvider(machine.uuid));
    var printState = ref.watch(printerProvider(machine.uuid).selectAs((d) => d.print.state));

    return switch (jrpcClientState) {
      AsyncValue(isLoading: true, isRefreshing: false) => FadingText('...'),
      AsyncData(value: var state) => state == ClientState.connected
          ? switch (printState) {
              AsyncData(value: PrintState.printing || PrintState.paused) => const _PrintProgressBar(circular: true),
              _ => MachineStateIndicator(machine),
            }
          : triedReconnect.value
              ? Icon(
                  FlutterIcons.disconnect_ant,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                )
              : InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    triedReconnect.value = true;
                    ref.read(jrpcClientProvider(machine.uuid)).ensureConnection();
                  },
                  child: Icon(Icons.restart_alt_outlined, size: 20, color: Theme.of(context).colorScheme.error),
                ),
      AsyncError(error: var e) => Tooltip(
          message: e.toString(),
          child: Icon(
            FlutterIcons.disconnect_ant,
            size: 20,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _PrintProgressBar extends ConsumerWidget {
  const _PrintProgressBar({super.key, this.circular = false});

  final bool circular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(printerCardMachineProvider);
    var progress = ref.watch(printerProvider(machine.uuid).selectAs((data) => data.printProgress)).valueOrFullNull ?? 0;
    var numberFormat = NumberFormat.percentPattern(context.locale.toStringWithSeparator());

    if (circular) {
      var themeData = Theme.of(context);
      return CircularPercentIndicator(
        radius: 20,
        lineWidth: 3,
        percent: progress,
        center: AutoSizeText(
          numberFormat.format(progress),
          maxLines: 1,
          minFontSize: 8,
          maxFontSize: 11,
        ),
        progressColor: themeData.colorScheme.primary,
        backgroundColor: themeData.useMaterial3
            ? themeData.colorScheme.surfaceVariant
            : themeData.colorScheme.primary.withOpacity(0.24),
      );
    }

    return LinearProgressIndicator(value: progress);
  }
}

class _Cam extends ConsumerWidget {
  const _Cam({super.key});

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
        child: FadeTransition(opacity: anim, child: child),
      ),
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
                  if (printState == PrintState.printing)
                    const Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _PrintProgressBar(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _imageBuilder(Widget imageTransformed) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      child: imageTransformed,
    );
  }
}
