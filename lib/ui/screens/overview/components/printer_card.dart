/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/enums/eta_data_source.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/history_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/client_state_extension.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/klippy_extension.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/time_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/webcam/webcam.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../routing/app_router.dart';
import '../../../components/machine_state_indicator.dart';

part 'printer_card.freezed.dart';
part 'printer_card.g.dart';

class PrinterCard extends HookConsumerWidget {
  const PrinterCard(this.machine, {super.key});

  static Widget loading() {
    return const _PrinterCardLoading();
  }

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    var machineUUID = machine.uuid;

    return AsyncGuard(
      animate: true,
      debugLabel: 'PrinterCard-$machineUUID}',
      toGuard: _printerCardControllerProvider(machine).selectAs((data) => true),
      childOnLoading: const _PrinterCardLoading(),
      childOnData: _PrinterCard(machine: machine),
    );
  }
}

class _PrinterCard extends StatelessWidget {
  const _PrinterCard({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context) {
    talker.info('Rebuilding _PrinterCard for ${machine.logName}');
    final themeData = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(machine: machine),
          Divider(height: 0),
          Flexible(child: _Cam(machine: machine)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _Body(machine: machine),
          ),
          if (themeData.useMaterial3) Gap(4),
        ],
      ),
    );
  }
}

class _PrinterCardLoading extends StatelessWidget {
  const _PrinterCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Card(
      child: Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: themeData.colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CardTitleSkeleton(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final clientState = ref.watch(_printerCardControllerProvider(machine).selectRequireValue((d) => d.jrpcClientState));

    talker.info('Rebuilding _Header for ${machine.logName}');

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          MachineStateIndicator(machine),
          Gap(8),
          Expanded(child: Text(machine.name, style: themeData.textTheme.titleMedium)),
          _ClientStateChip(state: clientState),
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
    talker.info('Rebuilding _Body for ${machine.logName}');
    final dateFormat = ref.watch(dateFormatServiceProvider).formatRelativeHm();
    final (clientState) = ref.watch(_printerCardControllerProvider(machine).selectRequireValue(
      (d) => d.jrpcClientState,
    ));

    final lastSeen = machine.lastSeen?.let(dateFormat) ?? tr('general.unknown');
    return switch (clientState) {
      ClientState.connected => _ClientConnectedBody(machine: machine),
      ClientState.disconnected => _ClientDisconnectedBody(machine: machine), // -> Actions
      ClientState.connecting => _ConnectingBody(lastSeen: lastSeen),
      ClientState.error => _ClientErrorBody(machine: machine), // -> Actions
    };
  }
}

class _ClientConnectedBody extends ConsumerWidget {
  const _ClientConnectedBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _ClientConnectedBody for ${machine.logName}');
    final (klippy, printState) =
        ref.watch(_printerCardControllerProvider(machine).selectRequireValue((d) => (d.klippy, d.printState)));

    talker.info('${machine.name} KLIPPY: ${klippy}');

    Widget klipy = switch (klippy.klippyState) {
      KlipperState.ready => _KlippyReadyBody(machine: machine),
      KlipperState.shutdown ||
      KlipperState.error ||
      KlipperState.unauthorized =>
        _KlippyErrorShutdownUnAuth(machine: machine),
      KlipperState.disconnected ||
      KlipperState.initializing ||
      KlipperState.startup =>
        _KlippyStartupInitializingDisconnected(machine: machine),
    };

    return klipy;
  }
}

class _KlippyReadyBody extends ConsumerWidget {
  const _KlippyReadyBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printState = ref.watch(_printerCardControllerProvider(machine).selectRequireValue((d) => d.printState));
    return switch (printState) {
      null => CircularProgressIndicator.adaptive(),
      PrintState.complete || PrintState.cancelled => _JobCompleteCancelledBody(machine: machine),
      PrintState.printing || PrintState.paused => _JobPrintingPausedBody(machine: machine),
      PrintState.error => _JobErrorBody(machine: machine),
      PrintState.standby => _JobStandbyBody(machine: machine),
    };
  }
}

class _KlippyStartupInitializingDisconnected extends HookConsumerWidget {
  const _KlippyStartupInitializingDisconnected({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    final klippy = ref.watch(_printerCardControllerProvider(machine).selectRequireValue((d) => d.klippy));

    Widget icon = switch (klippy.klippyState) {
      KlipperState.startup => Icon(Icons.rocket_launch_outlined, size: 36),
      KlipperState.initializing => RotationTransition(
          turns: animationController,
          child: Icon(Icons.settings_outlined, size: 36),
        ),
      KlipperState.disconnected => Icon(Icons.usb_off),
      _ => Icon(Icons.error_outline),
    };

    final themeData = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Gap(8),
        icon,
        Gap(4),
        Text(
          'components.machine_card.klippy_state.${klippy.klippyState.name}',
          style: themeData.textTheme.titleMedium,
        ).tr(),
        if (klippy.statusMessage.isNotEmpty == true)
          Text(klippy.statusMessage, style: themeData.textTheme.bodySmall, textAlign: TextAlign.center),
        Gap(8),
        _KlippyActions(machine: machine),
      ],
    );
  }
}

class _KlippyErrorShutdownUnAuth extends ConsumerWidget {
  const _KlippyErrorShutdownUnAuth({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klippy = ref.watch(_printerCardControllerProvider(machine).selectRequireValue((d) => d.klippy));

    var themeData = Theme.of(context);

    Color? onColor;
    Color? bgColor;
    IconData icon;

    switch (klippy.klippyState) {
      case KlipperState.shutdown:
        onColor = themeData.extension<CustomColors>()?.warning?.darken(28);
        bgColor = themeData.extension<CustomColors>()?.warning?.lighten(49);
        icon = Icons.power_off_outlined;
        break;

      case KlipperState.unauthorized:
        onColor = themeData.colorScheme.onTertiaryContainer;
        bgColor = themeData.colorScheme.tertiaryContainer;
        icon = Icons.lock_outline;
        break;
      case KlipperState.error:
      default:
        onColor = themeData.colorScheme.onErrorContainer;
        bgColor = themeData.colorScheme.errorContainer;
        icon = Icons.warning_amber;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap(8),
        Text(machine.httpUri.host, style: themeData.textTheme.bodySmall),
        Gap(4),
        Card(
          color: bgColor,
          shape: _border(context, onColor),
          margin: EdgeInsets.zero,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.all(4.0), child: Icon(icon, color: onColor)),
                Gap(8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('components.machine_card.klippy_state.${klippy.klippyState.name}'),
                        style: themeData.textTheme.bodyMedium?.copyWith(color: onColor),
                      ),
                      Text(
                        klippy.statusMessage,
                        style: themeData.textTheme.bodySmall?.copyWith(color: onColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _KlippyActions(machine: machine),
      ],
    );
  }

  ShapeBorder _border(BuildContext context, Color? borderColor) {
    /// If this property is null then [CardTheme.shape] of [ThemeData.cardTheme]
    /// is used. If that's null then the shape will be a [RoundedRectangleBorder]
    /// with a circular corner radius of 12.0 and if [ThemeData.useMaterial3] is
    /// false, then the circular corner radius will be 4.0.

    final themeData = Theme.of(context);

    final borderSide = BorderSide(color: borderColor ?? Color(0xFF000000), width: 0.5);
    final cardShape = themeData.cardTheme.shape;
    if (cardShape case RoundedRectangleBorder()) {
      return RoundedRectangleBorder(
        borderRadius: cardShape.borderRadius,
        side: borderSide,
      );
    }

    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(themeData.useMaterial3 ? 12 : 4),
      side: borderSide,
    );
  }
}

class _JobCompleteCancelledBody extends ConsumerWidget {
  const _JobCompleteCancelledBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _JobCompleteCancelledBody for ${machine.logName}');

    final (job, hasNoCam, printState, totalDuration, lastJob) = ref.watch(_printerCardControllerProvider(machine)
        .selectRequireValue((d) => (d.job, d.previewCam == null, d.printState!, d.totalDuration, d.lastJob)));

    final dateFormat = ref.watch(dateFormatServiceProvider).formatRelativeHm();

    final themeData = Theme.of(context);

    return Column(
      spacing: 4,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(machine.httpUri.host, style: themeData.textTheme.bodySmall),
                    Gap(4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FlutterIcons.file_outline_mco, size: 14),
                        Gap(4),
                        Flexible(child: Text(job!)),
                      ],
                    ),
                  ],
                ),
                if (hasNoCam) _PrintStateChip(printState: printState),
              ],
            ),
          ],
        ),
        _ProgressTracker(
          progress: 1,
          color: printState == PrintState.complete
              ? themeData.extension<CustomColors>()?.success
              : themeData.extension<CustomColors>()?.warning,
          leading: totalDuration != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time_outlined,
                      size: themeData.textTheme.bodySmall?.fontSize,
                      color: themeData.textTheme.bodySmall?.color,
                    ),
                    Gap(4),
                    Text(
                      '@:pages.dashboard.general.print_card.print_time: ${secondsToDurationText(totalDuration)}',
                      style: themeData.textTheme.bodySmall,
                    ).tr(),
                  ],
                )
              : null,
          trailing: lastJob != null
              ? Text(
                  dateFormat(lastJob.endTime),
                  style: themeData.textTheme.bodySmall,
                )
              : null,
        ),
        _ActionsWidget(machine: machine),
      ],
    );
  }
}

class _JobPrintingPausedBody extends ConsumerWidget {
  const _JobPrintingPausedBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _JobPrintingPausedBody for ${machine.logName}');
    final formatService = ref.watch(dateFormatServiceProvider);

    final (printProgress, job, hasNoCam, printState, eta) = ref.watch(_printerCardControllerProvider(machine)
        .selectRequireValue((d) => (d.printProgress!, d.job, d.previewCam == null, d.printState!, d.eta)));

    final dateFormat = eta?.isToday() == true ? formatService.Hm() : formatService.add_Hm(DateFormat.yMMMd());

    final themeData = Theme.of(context);

    return Column(
      spacing: 4,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(machine.httpUri.host, style: themeData.textTheme.bodySmall),
                    Gap(4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FlutterIcons.file_outline_mco, size: 14),
                        Gap(4),
                        Flexible(child: Text(job!)),
                      ],
                    ),
                  ],
                ),
                if (hasNoCam) _PrintStateChip(printState: printState),
              ],
            ),
          ],
        ),
        _ProgressTracker(
          progress: printProgress,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                printState == PrintState.printing ? Icons.access_time_outlined : Icons.pause_outlined,
                size: themeData.textTheme.bodySmall?.fontSize,
                color: themeData.textTheme.bodySmall?.color,
              ),
              Gap(4),
              Text(
                '@:pages.dashboard.general.print_card.eta: ${eta?.let(dateFormat.format) ?? '--:--'}',
                style: themeData.textTheme.bodySmall,
              ).tr(),
            ],
          ),
        ),
        _ActionsWidget(machine: machine),
      ],
    );
  }
}

class _JobStandbyBody extends ConsumerWidget {
  const _JobStandbyBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _JobStandbyBody for ${machine.logName}');
    final (printProgress, job, hasNoCam, eta, lastJob) = ref.watch(_printerCardControllerProvider(machine)
        .selectRequireValue((d) => (d.printProgress, d.job, d.previewCam == null, d.eta, d.lastJob)));

    final themeData = Theme.of(context);
    return Column(
      spacing: 4,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              spacing: 4,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(machine.httpUri.host, style: themeData.textTheme.bodySmall),
                Text('components.machine_card.waiting_for_job').tr(),
              ],
            ),
            if (hasNoCam) _PrintStateChip(printState: PrintState.standby),
          ],
        ),
        if (lastJob?.endTime != null) Text(lastActivity(lastJob!.endTime), style: themeData.textTheme.bodySmall),
        _ActionsWidget(machine: machine),
      ],
    );
  }

  String lastActivity(DateTime time) {
    final today = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    final normalized = time.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

    final days = today.difference(normalized).inDays;

    return plural('components.machine_card.last_activity', days);
  }
}

class _JobErrorBody extends ConsumerWidget {
  const _JobErrorBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _JobErrorBody for ${machine.logName}');
    final (message, job, hasNoCam) = ref.watch(
        _printerCardControllerProvider(machine).selectRequireValue((d) => (d.jobMessage, d.job, d.previewCam == null)));

    final themeData = Theme.of(context);

    return Column(
      spacing: 4,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(machine.httpUri.host, style: themeData.textTheme.bodySmall),
                    Gap(4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FlutterIcons.file_outline_mco, size: 14),
                        Gap(4),
                        Flexible(child: Text(job!)),
                      ],
                    ),
                  ],
                ),
                if (hasNoCam) _PrintStateChip(printState: PrintState.error),
              ],
            ),
          ],
        ),
        if (message != null)
          Card(
            color: themeData.colorScheme.errorContainer,
            margin: EdgeInsets.zero,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                message,
                style: themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.onErrorContainer),
              ),
            ),
          ),
        _ActionsWidget(machine: machine),
      ],
    );
  }
}

class _ClientDisconnectedBody extends ConsumerWidget {
  const _ClientDisconnectedBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _ClientDisconnectedBody');
    final dateFormat = ref.watch(dateFormatServiceProvider).formatRelativeHm();
    final lastSeen = machine.lastSeen?.let(dateFormat) ?? tr('general.unknown');

    final themeData = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Gap(8),
        Icon(Icons.wifi_off, size: 36, color: themeData.disabledColor),
        Gap(4),
        Text('components.machine_card.client_state.disconnected', style: themeData.textTheme.titleMedium).tr(),
        Text('@:components.machine_card.last_seen: $lastSeen', style: themeData.textTheme.bodySmall).tr(),
        Gap(8),
        _JrpcActions(machine: machine),
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
    final errorMessage = ref.watch(_printerCardControllerProvider(machine).selectRequireValue((d) => d.jrpcError));

    final lastSeen = machine.lastSeen?.let(dateFormat) ?? tr('general.unknown');
    final themeData = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Gap(8),
        Icon(Icons.warning_amber, size: 36, color: themeData.colorScheme.error),
        Gap(4),
        Text('client_state.error', style: themeData.textTheme.titleMedium?.copyWith(color: themeData.colorScheme.error))
            .tr(),
        Text('@:components.machine_card.last_seen: $lastSeen', style: themeData.textTheme.bodySmall).tr(),
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
                  errorMessage!,
                  style: themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.onErrorContainer),
                ),
              ),
            ),
          ),
        ],
        Gap(8),
        _JrpcActions(machine: machine),
      ],
    );
  }
}

class _ConnectingBody extends HookWidget {
  const _ConnectingBody({super.key, required this.lastSeen});

  final String lastSeen;

  @override
  Widget build(BuildContext context) {
    AnimationController animationController = useAnimationController(
      duration: const Duration(seconds: 1),
    )..repeat();

    var themeData = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Gap(8),
        RotationTransition(
          turns: animationController,
          child: Icon(Icons.autorenew, size: 36),
        ),
        Gap(4),
        Text('components.connection_watcher.trying_connect', style: themeData.textTheme.titleMedium).tr(),
        Text('@:components.machine_card.last_seen: $lastSeen', style: themeData.textTheme.bodySmall).tr(),
      ],
    );
  }
}

class _Cam extends ConsumerWidget {
  const _Cam({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _Cam for ${machine.logName}');
    final (previewCam, isJrpcConnected) = ref.watch(_printerCardControllerProvider(machine)
        .selectRequireValue((d) => (d.previewCam, d.jrpcClientState == ClientState.connected)));
    final controller = ref.watch(_printerCardControllerProvider(machine).notifier);
    if (previewCam == null) return const SizedBox.shrink();
    final themeData = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Webcam(
            webcamInfo: previewCam,
            machine: machine,
            showRemoteIndicator: false,
            stackContent: [
              if (isJrpcConnected)
                Positioned.fill(
                  top: themeData.useMaterial3 ? 4 : 0,
                  left: 8,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Consumer(builder: (context, ref, _) {
                      final printState =
                          ref.watch(_printerCardControllerProvider(machine).selectRequireValue((d) => d.printState));
                      if (printState == null) return const SizedBox.shrink();
                      return _PrintStateChip(printState: printState);
                    }),
                  ),
                ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.aspect_ratio),
                    tooltip: tr('pages.dashboard.general.cam_card.fullscreen'),
                    onPressed: controller.openPreviewCamInFullscreen,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 0),
        ],
      ),
    );
  }
}

class _PrintStateChip extends HookWidget {
  const _PrintStateChip({super.key, required this.printState});

  final PrintState printState;

  @override
  Widget build(BuildContext context) {
    AnimationController animationController = useAnimationController(
      duration: const Duration(seconds: 1),
    )..repeat();

    Widget? avatar = switch (printState) {
      PrintState.printing => RotationTransition(
          turns: animationController,
          child: Icon(Icons.autorenew),
        ),
      PrintState.error => Icon(Icons.warning_amber),
      PrintState.paused => Icon(Icons.pause_outlined),
      PrintState.complete => Icon(Icons.done),
      PrintState.cancelled => Icon(Icons.do_not_disturb_on_outlined),
      _ => null
    };

    return Chip(
      avatar: avatar,
      label: Text(printState.displayName),
      labelPadding: EdgeInsets.only(right: 4, left: avatar == null ? 4 : 0),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ClientStateChip extends HookWidget {
  const _ClientStateChip({super.key, required this.state});

  final ClientState state;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    AnimationController animationController = useAnimationController(
      duration: const Duration(seconds: 1),
    )..repeat();

    var customColors = themeData.extension<CustomColors>();
    Color? fg;
    Color? bg;
    String suffix = '';
    Widget? avatar;
    switch (state) {
      case ClientState.connecting:
        avatar = RotationTransition(
          turns: animationController,
          child: Icon(Icons.autorenew),
        );
        suffix = '…';
        fg = customColors?.info;
        bg = fg?.lighten(36);
        break;
      case ClientState.connected:
        avatar = Icon(Icons.wifi);
        fg = customColors?.success;
        bg = fg?.lighten(40);
        break;
      case ClientState.disconnected:
        avatar = Icon(Icons.wifi_off);
        fg = themeData.colorScheme.onSurface;
        bg = themeData.colorScheme.surfaceContainerHigh;
        break;
      case ClientState.error:
        avatar = Icon(Icons.warning_amber);
        fg = themeData.colorScheme.error;
        bg = themeData.colorScheme.errorContainer;
        break;
    }

    return Chip(
      elevation: 0,
      avatar: avatar,
      backgroundColor: bg,
      iconTheme: IconThemeData(color: fg),
      label: Text(state.displayName + suffix, style: TextStyle(color: fg)),
      labelPadding: EdgeInsets.only(right: 4, left: avatar == null ? 4 : 0),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ProgressTracker extends StatelessWidget {
  const _ProgressTracker({super.key, required this.progress, this.color, this.leading, this.trailing});

  final double progress;
  final Color? color;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    final numberFormat = NumberFormat.percentPattern(context.locale.toStringWithSeparator());

    return Column(
      spacing: 4,
      children: [
        LinearProgressIndicator(
          value: progress,
          color: color,
          borderRadius: BorderRadius.circular(2),
          backgroundColor: themeData.colorScheme.surfaceContainerHigh,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            leading ?? const SizedBox.shrink(),
            if (trailing != null) trailing!,
            if (trailing == null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(numberFormat.format(progress), style: themeData.textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _JrpcActions extends ConsumerWidget {
  const _JrpcActions({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _KlippyActions for ${machine.logName}');
    final jrpcState = ref.watch(_printerCardControllerProvider(machine).selectRequireValue((d) => d.jrpcClientState));
    final controller = ref.watch(_printerCardControllerProvider(machine).notifier);

    final themeData = Theme.of(context);

    final buttons = <Widget>[];

    switch (jrpcState) {
      // Error -> Reconnect, Settings
      // disconnected -> Reconnect

      case ClientState.disconnected:
        buttons.add(ElevatedButton.icon(
          onPressed: controller.connectJrpcClient,
          label: Text('components.connection_watcher.reconnect').tr(),
          icon: Icon(Icons.restart_alt),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
          ),
        ));
        break;

      case ClientState.error:
        buttons.add(ElevatedButton.icon(
          onPressed: controller.connectJrpcClient,
          label: Text('general.retry').tr(),
          icon: Icon(Icons.restart_alt),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
          ),
        ));
        buttons.add(ElevatedButton(
          onPressed: controller.openMachineSettings,
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

class _KlippyActions extends ConsumerWidget {
  const _KlippyActions({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _KlippyActions for ${machine.logName}');
    final klippy = ref.watch(_printerCardControllerProvider(machine).selectRequireValue((d) => d.klippy));
    final controller = ref.watch(_printerCardControllerProvider(machine).notifier);

    final themeData = Theme.of(context);

    final buttons = <Widget>[];

    switch (klippy.klippyState) {
      // StartUp -> Nix oder refresh state
      // Initializing -> Nix oder refresh state

      // Shutdown -> Restart FW, Restart Klipper
      // Error -> Restart Fw, Restart Klipper

      // UnAuth -> Edit Config or nothing

      case KlipperState.shutdown:
      case KlipperState.error:
        buttons.add(ElevatedButton.icon(
          onPressed: controller.restartKlippy,
          label: Text('pages.dashboard.general.restart_klipper').tr(),
          icon: Icon(Icons.restart_alt),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.colorScheme.error,
            foregroundColor: themeData.colorScheme.onError,
          ),
        ));
        if (klippy.klippyConnected) {
          buttons.add(ElevatedButton.icon(
            onPressed: controller.restartMcus,
            label: Text('pages.dashboard.general.restart_mcu').tr(),
            icon: Icon(Icons.restart_alt),
            style: ElevatedButton.styleFrom(
              iconSize: 18,
              backgroundColor: themeData
                  .extension<CustomColors>()
                  ?.warning,
              foregroundColor: themeData
                  .extension<CustomColors>()
                  ?.onWarning,
            ),
          ));
        }
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

class _ActionsWidget extends ConsumerWidget {
  const _ActionsWidget({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _ActionsWidget for ${machine.logName}');
    final printState = ref.watch(_printerCardControllerProvider(machine).selectRequireValue((d) => d.printState));
    final controller = ref.watch(_printerCardControllerProvider(machine).notifier);

    final themeData = Theme.of(context);

    final buttons = <Widget>[];

    switch (printState ?? PrintState.standby) {
      case PrintState.printing: // Checked
        buttons.add(ElevatedButton.icon(
          onPressed: controller.pauseJob,
          label: Text('general.pause').tr(),
          icon: Icon(Icons.pause_outlined),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData
                .extension<CustomColors>()
                ?.warning,
            foregroundColor: themeData
                .extension<CustomColors>()
                ?.onWarning,
          ),
        ));
        buttons.add(ElevatedButton(
          onPressed: controller.emergencyStop,
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.colorScheme.error,
            foregroundColor: themeData.colorScheme.onError,
          ),
          child: Text('EMS'),
        ));
        break;
      case PrintState.paused: // Checked
        buttons.add(ElevatedButton.icon(
          onPressed: controller.resumeJob,
          label: Text('general.resume').tr(),
          icon: Icon(Icons.play_arrow_outlined),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
          ),
        ));
        buttons.add(ElevatedButton(
          onPressed: controller.cancelJob,
          style: ElevatedButton.styleFrom(
            backgroundColor: themeData.colorScheme.error,
            foregroundColor: themeData.colorScheme.onError,
          ),
          child: Text('general.cancel').tr(),
        ));
        break;
      case PrintState.standby:
        buttons.add(ElevatedButton(
          onPressed: controller.openFileBrowser,
          style: ElevatedButton.styleFrom(
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
          ),
          child: Text('components.machine_card.new_print').tr(),
        ));
        break;
      case PrintState.cancelled:
      case PrintState.complete:
        buttons.add(ElevatedButton.icon(
          onPressed: controller.reprintFile,
          label: Text('pages.dashboard.general.print_card.reprint').tr(),
          icon: Icon(Icons.history),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
          ),
        ));
        buttons.add(ElevatedButton(
          onPressed: controller.resetPrintState,
          style: ElevatedButton.styleFrom(
            backgroundColor: themeData.colorScheme.secondary,
            foregroundColor: themeData.colorScheme.onSecondary,
          ),
          child: Text('pages.dashboard.general.print_card.reset').tr(),
        ));

        break;
      case PrintState.error: // Checked
        buttons.add(ElevatedButton(
          onPressed: controller.resetPrintState,
          style: ElevatedButton.styleFrom(
            backgroundColor: themeData.colorScheme.secondary,
            foregroundColor: themeData.colorScheme.onSecondary,
          ),
          child: Text('pages.dashboard.general.print_card.reset').tr(),
        ));
        break;
    }

    return Row(
      spacing: 6,
      children: [
        for (var button in buttons) Expanded(child: button),
        IconButton(
          onPressed: controller.openMachineDashboard,
          icon: Icon(Icons.keyboard_arrow_right_outlined),
        ),
      ],
    );
  }
}

@riverpod
class _PrinterCardController extends _$PrinterCardController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  SelectedMachineService get _selectedMachineService => ref.read(selectedMachineServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(this.machine.uuid));

  KlippyService get _klippyService => ref.read(klipperServiceProvider(this.machine.uuid));

  JsonRpcClient get _jrpcClient => ref.read(jrpcClientProvider(this.machine.uuid));

  @override
  Future<_Model> build(Machine machine) async {
    final etaSourceSettings = ref
        .watch(listSettingProvider(AppSettingKeys.etaSources,
            AppSettingKeys.etaSources.defaultValue as List<ETADataSource>, ETADataSource.fromJson))
        .cast<ETADataSource>()
        .toSet();

    // this isnt the future because klippy readyness might prevent it from loading!
    final printerData = ref.watch(printerProvider(machine.uuid).select((d) {
      final v = d.valueOrNull;
      return (
        v?.print.state,
        v?.printProgress,
        v?.print.filename.unless(v.print.filename.isEmpty),
        v?.calcEta(etaSourceSettings),
        v?.calcRemainingTimeAvg(etaSourceSettings),
        v?.print.totalDuration,
        v?.print.message.unless(v.print.message.isEmpty),
      );
    }));

    final jrpcStateFuture = ref.watch(jrpcClientStateProvider(machine.uuid).future);
    final previewCamFuture = _previewCam();
    final jrpcError = ref.watch(jrpcClientProvider(machine.uuid).select((d) => d.errorReason));

    // We catch any errors because if the klipper element is missing we dont have access to this api. For now we ignore them, cleaner approach would be to just do null if its not available!
    final lastJobFuture = ref.watch(lastJobProvider(machine.uuid).future).onError((_, __) => null);

    final klippyFuture = ref.watch(klipperProvider(machine.uuid).future);

    final result = await Future.wait([jrpcStateFuture, lastJobFuture, previewCamFuture, klippyFuture]);

    final jrpcState = result[0] as ClientState;
    final lastJob = result[1] as HistoricalPrintJob?;
    final previewCam = result[2] as WebcamInfo?;
    final klippy = result[3] as KlipperInstance;

    var model = _Model(
      previewCam: previewCam,
      klippy: klippy,
      jrpcClientState: jrpcState,
      printState: printerData.$1,
      printProgress: printerData.$2,
      job: printerData.$3,
      totalDuration: printerData.$6,
      remaining: printerData.$5,
      eta: printerData.$4,
      jobMessage: printerData.$7,
      jrpcError: jrpcError?.toString(),
      lastJob: lastJob,
    );
    talker.info('PrinterCardModel for ${machine.logName} created: $model');

    return model;
  }

  Future<WebcamInfo?> _previewCam() async {
    final isSupporter = ref.watch(isSupporterProvider);

    final cams = await ref.watch(allSupportedWebcamInfosProvider(this.machine.uuid).future);
    if (cams.isEmpty) {
      return null;
    }

    final webcamIndexKey = CompositeKey.keyWithString(UtilityKeys.webcamIndex, this.machine.uuid);
    final selIndex = ref.watch(intSettingProvider(webcamIndexKey)).clamp(0, cams.length - 1);

    WebcamInfo? previewCam = cams.elementAtOrNull(selIndex);

    // If there is no preview cam or the preview cam is not for supporters or the user is a supporter
    if (previewCam == null || previewCam.service.forSupporters == false || isSupporter) {
      return previewCam;
    }

    // If the user is not a supporter and the cam he selected is for supporters only just select the first cam that is not for supporters
    return cams.firstWhereOrNull((element) => element.service.forSupporters == false);
  }

  void openMachineDashboard() {
    _goRouter.pushNamed(AppRoute.dashBoard.name);
  }

  void openMachineSettings() {
    _goRouter.pushNamed(AppRoute.printerEdit.name, extra: this.machine);
  }

  void openFileBrowser() {
    //TODO: This should be replaced via a bottom sheet!
    _selectedMachineService.selectMachine(this.machine);
    _goRouter.push('/files/gcodes');
  }

  void openPreviewCamInFullscreen() {
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
      extra: {'machine': this.machine, 'selectedCam': cam},
    );
  }

  void reprintFile() => _printerService.reprintCurrentFile();

  void resetPrintState() => _printerService.resetPrintStat();

  void pauseJob() {
    _dialogService
        .showConfirm(
      title: tr('dialogs.confirm_print_pause.title'),
      body: tr('dialogs.confirm_print_pause.body'),
      actionLabel: tr('general.pause'),
    )
        .then((res) {
      if (res?.confirmed == true) {
        _printerService.pausePrint();
      }
    });
  }

  void resumeJob() => _printerService.resumePrint();

  void cancelJob() {
    _dialogService
        .showDangerConfirm(
      dismissLabel: tr('general.abort'),
      actionLabel: tr('general.cancel'),
      title: tr('dialogs.confirm_print_cancelation.title'),
      body: tr('dialogs.confirm_print_cancelation.body'),
    )
        .then((res) {
      if (res?.confirmed == true) {
        _printerService.cancelPrint();
      }
    });
  }

  void emergencyStop() async {
    if (ref.read(settingServiceProvider).readBool(AppSettingKeys.confirmEmergencyStop, true)) {
      var result = await ref.read(dialogServiceProvider).showDangerConfirm(
            title: tr('pages.dashboard.ems_confirmation.title'),
            body: tr('pages.dashboard.ems_confirmation.body'),
            actionLabel: tr('pages.dashboard.ems_confirmation.confirm'),
          );
      if (!(result?.confirmed ?? false)) return;
    }

    _klippyService.emergencyStop();
  }

  void restartKlippy() {
    talker.info('Restarting Klipper for ${this.machine.logName}');
    _klippyService.restartKlipper().ignore();
  }

  void restartMcus() {
    talker.info('Restarting MCUs for ${this.machine.logName}');
    _klippyService.restartMCUs();
  }

  void connectJrpcClient() => _jrpcClient.openChannel().ignore();

  @override
  bool updateShouldNotify(AsyncValue<_Model> previous, AsyncValue<_Model> next) {
    final wasLoading = previous.isLoading;
    final isLoading = next.isLoading;

    final loadingTransition = (wasLoading || isLoading) && wasLoading != isLoading;
    final progressEpsilon =
        previous.valueOrNull?.printProgress?.closeTo(next.valueOrNull?.printProgress ?? 0, 0.01) != false;

    return loadingTransition && progressEpsilon ||
        previous.valueOrNull?.printState != next.valueOrNull?.printState ||
        previous.valueOrNull?.klippy != next.valueOrNull?.klippy ||
        previous.valueOrNull?.jrpcClientState != next.valueOrNull?.jrpcClientState ||
        previous.valueOrNull?.previewCam != next.valueOrNull?.previewCam ||
        previous.valueOrNull?.job != next.valueOrNull?.job ||
        previous.valueOrNull?.remaining != next.valueOrNull?.remaining ||
        previous.valueOrNull?.eta != next.valueOrNull?.eta ||
        previous.valueOrNull?.totalDuration != next.valueOrNull?.totalDuration ||
        previous.valueOrNull?.jobMessage != next.valueOrNull?.jobMessage ||
        previous.valueOrNull?.jrpcError != next.valueOrNull?.jrpcError ||
        previous.valueOrNull?.lastJob != next.valueOrNull?.lastJob;
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    WebcamInfo? previewCam,
    required ClientState jrpcClientState,
    required KlipperInstance klippy,
    required PrintState? printState,
    required double? printProgress,
    String? job,
    double? totalDuration,
    int? remaining,
    DateTime? eta,
    String? jobMessage,
    String? jrpcError,
    HistoricalPrintJob? lastJob,
  }) = __Model;
}
