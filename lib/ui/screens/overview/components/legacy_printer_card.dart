/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/mobileraker_icon_button.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/webcam/webcam.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../routing/app_router.dart';
import '../../../components/machine_state_indicator.dart';

part 'legacy_printer_card.freezed.dart';
part 'legacy_printer_card.g.dart';

class LegacyPrinterCard extends HookConsumerWidget {
  const LegacyPrinterCard(this.machine, {super.key});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _Cam(machine: machine)),
          _Body(machine: machine),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_printerCardControllerProvider(machine).notifier);
    final themeData = Theme.of(context);

    // talker.info('Rebuilding _Body for ${machine.logName}');

    return InkWell(
      onTap: controller.onTapTile,
      // onLongPress: singlePrinterCardController.onLongPressTile,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(machine.name, style: themeData.textTheme.titleMedium),
                  Text(
                    machine.httpUri.toString(),
                    style: themeData.textTheme.bodySmall,
                  ),
                  Flexible(
                    child: Consumer(builder: (context, ref, child) {
                      final model = ref.watch(_printerCardControllerProvider(machine));

                      return AnimatedSwitcher(
                        duration: kThemeAnimationDuration,
                        // duration: const Duration(seconds: 2),
                        child: switch (model) {
                          AsyncValue(hasValue: true, value: _Model(jrpcClientState: ClientState.error)) => Text(
                                  key: const Key('cs-e'),
                                  'pages.printer_edit.fetch_error_hint',
                                  style: themeData.textTheme.bodySmall)
                              .tr(),
                          AsyncValue(
                            hasValue: true,
                            value: _Model(:final printState, jrpcClientState: ClientState.connected)
                          ) =>
                            Text(key: const Key('cs-c'), printState.displayName, style: themeData.textTheme.bodySmall),
                          _ => Text(
                              key: const Key('cs-w'),
                              '',
                              style: themeData.textTheme.bodySmall), // Just a placeholder to prevent jumping UI
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
            _Trailing(machine: machine),
          ],
        ),
      ),
    );
  }
}

class _Trailing extends HookConsumerWidget {
  const _Trailing({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triedReconnect = useState(false);
    final model = ref.watch(_printerCardControllerProvider(machine));

    talker.info('Rebuilding _Trailing for ${machine.logName} $model');

    final themeData = Theme.of(context);
    return switch (model) {
      // Handle connected
      AsyncValue(
        hasValue: true,
        value: _Model(jrpcClientState: ClientState.connected, printState: PrintState.printing, :final printProgress)
      ) =>
        _PrintProgressBar(progress: printProgress, circular: true),
      AsyncValue(
        hasValue: true,
        value: _Model(jrpcClientState: ClientState.connected, printState: PrintState.paused)
      ) =>
        const Icon(Icons.pause_circle_outline, size: 20),
      AsyncValue(hasValue: true, value: _Model(jrpcClientState: ClientState.connected)) =>
        MachineStateIndicator(machine),
      // Handle other jrpc states
      AsyncData() when triedReconnect.value => Icon(
          FlutterIcons.disconnect_ant,
          size: 20,
          color: themeData.colorScheme.error,
        ),
      AsyncData() => MobilerakerIconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.restart_alt_outlined),
          color: themeData.extension<CustomColors>()?.danger,
          onPressed: () {
            triedReconnect.value = true;
            ref.read(jrpcClientProvider(machine.uuid)).ensureConnection();
          },
        ),
      AsyncError(error: var e) => Tooltip(
          message: e.toString(),
          child: Icon(
            FlutterIcons.disconnect_ant,
            size: 20,
            color: themeData.colorScheme.error,
          ),
        ),
      AsyncValue(isLoading: true, isRefreshing: false) => FadingText('...'),
      _ => const SizedBox.shrink(),
    };
  }
}

class _PrintProgressBar extends ConsumerWidget {
  const _PrintProgressBar({super.key, required this.progress, this.circular = false});

  final double progress;
  final bool circular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (circular) {
      final numberFormat = NumberFormat.percentPattern(context.locale.toStringWithSeparator());
      final themeData = Theme.of(context);
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
            ? themeData.colorScheme.surfaceContainer
            : themeData.colorScheme.primary.withValues(alpha: 0.24),
      );
    }

    return LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.transparent,
    );
  }
}

class _Cam extends ConsumerWidget {
  const _Cam({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // talker.info('Rebuilding _Cam for ${machine.logName}');
    final model = ref.watch(_printerCardControllerProvider(machine)).valueOrNull;
    final controller = ref.watch(_printerCardControllerProvider(machine).notifier);
    if (model == null || model.previewCam == null) return const SizedBox.shrink();

    talker.warning('Rebuilding _Cam for ${machine.logName} with ${model}');

    return Align(
      alignment: Alignment.bottomCenter,
      child: Webcam(
        webcamInfo: model.previewCam!,
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
                onPressed: controller.onFullScreenTap,
              ),
            ),
          ),
          if (model.printState == PrintState.printing)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _PrintProgressBar(progress: model.printProgress!),
              ),
            ),
        ],
      ),
    );

    // return AnimatedSwitcher(
    //   switchInCurve: Curves.easeInOutBack,
    //   duration: const Duration(milliseconds: 600),
    //   transitionBuilder: (child, anim) => SizeTransition(
    //     sizeFactor: anim,
    //     child: FadeTransition(opacity: anim, child: child),
    //   ),
    //   child: (webcamInfo == null)
    //       ? const SizedBox.shrink()
    //       : ,
    // );
  }
}

@riverpod
class _PrinterCardController extends _$PrinterCardController {
  SelectedMachineService get _selectedMachineService => ref.read(selectedMachineServiceProvider);

  GoRouter get _goRouter => ref.read(goRouterProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  @override
  Future<_Model> build(Machine machine) async {
    final jrpcStateFuture = ref.watch(jrpcClientStateProvider(machine.uuid).future);
    final jrpcState = await jrpcStateFuture;

    if (jrpcState != ClientState.connected) {
      return _Model(jrpcClientState: jrpcState, printState: PrintState.error, printProgress: 0);
    }

    final previewCamFuture = ref.watch(activeWebcamInfoForMachineProvider(machine.uuid).future);
    final printerDataFuture =
        ref.watch(printerProvider(machine.uuid).selectAsync((d) => (d.print.state, d.printProgress)));

    final printerData = await printerDataFuture;
    final previewCam = await previewCamFuture;

    return _Model(
      previewCam: previewCam,
      jrpcClientState: jrpcState,
      printState: printerData.$1,
      printProgress: printerData.$2,
    );
  }

  onTapTile() {
    ref.read(selectedMachineServiceProvider).selectMachine(machine);
    _goRouter.pushNamed(AppRoute.dashBoard.name);
  }

  onLongPressTile() {
    _selectedMachineService.selectMachine(machine);
    _goRouter.pushNamed(AppRoute.printerEdit.name, extra: machine);
  }

  onFullScreenTap() {
    var cam = state.requireValue.previewCam;
    if (cam == null) {
      return _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: 'Could not open cam',
        message: 'Unexpected error occurred. Please try again.',
      ));
    }
    _goRouter.pushNamed(
      AppRoute.fullCam.name,
      extra: {'machine': machine, 'selectedCam': cam},
    );
  }

  @override
  bool updateShouldNotify(AsyncValue<_Model> previous, AsyncValue<_Model> next) {
    final wasLoading = previous.isLoading;
    final isLoading = next.isLoading;

    final loadingTransition = (wasLoading || isLoading) && wasLoading != isLoading;
    final progressEpsilon =
        previous.valueOrNull?.printProgress.closeTo(next.valueOrNull?.printProgress ?? 0, 0.01) != false;

    return loadingTransition && progressEpsilon;
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    WebcamInfo? previewCam,
    required ClientState jrpcClientState,
    required PrintState printState,
    required double printProgress,
  }) = __Model;
}
