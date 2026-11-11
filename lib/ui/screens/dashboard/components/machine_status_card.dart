/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/service/moonraker/history_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/animation/SizeAndFadeTransition.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/historical_print_job_extension.dart';
import 'package:common/util/extensions/klippy_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/screens/files/components/remote_file_icon.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../service/ui/dialog_service_impl.dart';
import 'toolhead_info/toolhead_info_table.dart';

part 'machine_status_card.freezed.dart';
part 'machine_status_card.g.dart';

class MachineStatusCard extends HookConsumerWidget {
  const MachineStatusCard({super.key, required this.machineUUID});

  static Widget preview() {
    return const _MachineStatusCardPreview();
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No keep-alive: state is derived synchronously from providers, so off-screen instances can be disposed.
    talker.info('Rebuilding MachineStatusCard for $machineUUID');

    return AsyncGuard(
      animate: true,
      // debugLabel: 'MachineStatusCard-$machineUUID',
      toGuard: _machineStatusCardControllerProvider(machineUUID).selectAs((data) => true),
      childOnLoading: const _MachineStatusCardLoading(),
      childOnData: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CardTitle(machineUUID: machineUUID),
            _KlippyStateActionButtons(machineUUID: machineUUID),
            _M117Message(machineUUID: machineUUID),
            _ExcludeObject(machineUUID: machineUUID),
            Consumer(builder: (ctx, iref, _) {
              var (model, isCC) = iref.watch(_machineStatusCardControllerProvider(machineUUID)
                  .selectRequireValue((data) => (data.showToolheadTable, data.isCompleteOrCancelled)));
              // talker.info('Rebuilding ToolheadInfoTable for $machineUUID');
              return AnimatedSizeAndFade(
                sizeDuration: kThemeAnimationDuration,
                fadeDuration: kThemeAnimationDuration,
                child: model
                    ? Column(
                        key: Key('ShowTable-cc-$isCC'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Divider(thickness: 1, height: 0),
                          ToolheadInfoTable(
                            machineUUID: machineUUID,
                            rowsToShow: isCC
                                ? [ToolheadInfoTable.SUMMARY_ROW]
                                : [
                                    ToolheadInfoTable.POS_ROW,
                                    ToolheadInfoTable.MOV_ROW,
                                  ],
                          ),
                        ],
                      )
                    : const SizedBox.shrink(key: Key('NoTable')),
              );
            }),
            _PrintAgain(machineUUID: machineUUID),
          ],
        ),
      ),
    );
  }
}

class _MachineStatusCardPreview extends HookWidget {
  static const String _machineUUID = 'preview';

  const _MachineStatusCardPreview({super.key});

  @override
  Widget build(BuildContext context) {
    useAutomaticKeepAlive();
    return ProviderScope(
      overrides: [
        _machineStatusCardControllerProvider(_machineUUID).overrideWith(_MachineStatusCardPreviewController.new),
        // The preview has no printer to fetch a history from.
        jobHistoryProvider(_machineUUID, null).overrideWith((ref) => const <HistoricalPrintJob>[]),
      ],
      child: const MachineStatusCard(machineUUID: _machineUUID),
    );
  }
}

class _MachineStatusCardLoading extends StatelessWidget {
  const _MachineStatusCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Card(
      child: Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: themeData.colorScheme.background,
        child: const Padding(
          padding: EdgeInsets.only(top: 3.0),
          child: CardTitleSkeleton(),
        ),
      ),
    );
  }
}

class _CardTitle extends ConsumerWidget {
  const _CardTitle({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // var controller = ref.watch(_spoolmanCardControllerProvider(machineUUID).notifier);

    var klippyCanReceiveCommands = ref.watch(
        _machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.klippyCanReceiveCommands));

    var printState =
        ref.watch(_machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.printState));
    return ListTile(
      contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
      leading: Icon(klippyCanReceiveCommands ? MaterialCommunityIcons.monitor_dashboard : AntDesign.disconnect),
      title: _Title(machineUUID: machineUUID),
      subtitle: switch (printState) {
        PrintState.printing || PrintState.paused || PrintState.complete || PrintState.cancelled => Text(
            ref.watch(_machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.filename))),
        PrintState.error =>
          Text(ref.watch(_machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.message))),
        _ => null,
      },
      trailing: _Trailing(machineUUID: machineUUID),
    );
  }
}

class _Title extends ConsumerWidget {
  const _Title({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyCanReceiveCommands = ref.watch(
        _machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.klippyCanReceiveCommands));

    final Widget text;
    if (klippyCanReceiveCommands) {
      text = Text(
        key: const ValueKey('klippyState'),
        ref.watch(_machineStatusCardControllerProvider(machineUUID)
            .selectRequireValue((data) => data.printState.displayName)),
      );
    } else {
      var klippyStatus = ref.watch(
          _machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.klippyStatusMessage));
      text = Text(
        key: Key(klippyStatus),
        klippyStatus,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      transitionBuilder: (child, animation) => SizeAndFadeTransition(
        sizeAndFadeFactor: animation,
        child: child,
      ),
      child: text,
    );
  }
}

class _Trailing extends ConsumerWidget {
  const _Trailing({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_machineStatusCardControllerProvider(machineUUID).notifier);
    // Here it is fine to just use the model directly, as the most updates will be triggered via the progress which we are using here
    var model = ref.watch(_machineStatusCardControllerProvider(machineUUID).requireValue());

    var themeData = Theme.of(context);
    // Slider()
    return switch (model.printState) {
      PrintState.printing => CircularPercentIndicator(
          radius: 25,
          lineWidth: 4,
          percent: model.progress,
          center: Text(NumberFormat.percentPattern(context.locale.toStringWithSeparator()).format(model.progress)),
          progressColor: (model.printState == PrintState.complete)
              ? themeData.extension<CustomColors>()?.success
              : themeData.colorScheme.primary,
          backgroundColor: themeData.useMaterial3
              ? themeData.colorScheme.surfaceContainer
              : themeData.colorScheme.primary.withValues(alpha: 0.24),
        ),
      PrintState.error => TextButton.icon(
          onPressed: model.klippyCanReceiveCommands ? controller.resetPrintState : null,
          icon: const Icon(Icons.restart_alt_outlined),
          label: const Text('pages.dashboard.general.print_card.reset').tr(),
        ),
      PrintState.complete || PrintState.cancelled => PopupMenuButton(
          enabled: model.klippyCanReceiveCommands,
          padding: EdgeInsets.zero,
          position: PopupMenuPosition.over,
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: model.klippyCanReceiveCommands,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onTap: controller.resetPrintState,
              child: Row(
                children: [
                  Icon(
                    Icons.restart_alt_outlined,
                    color: themeData.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'pages.dashboard.general.print_card.reset',
                    style: TextStyle(color: themeData.colorScheme.primary),
                  ).tr(),
                ],
              ),
            ),
            PopupMenuItem(
              enabled: model.klippyCanReceiveCommands,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onTap: controller.reprint,
              child: Row(
                children: [
                  Icon(
                    MaterialCommunityIcons.printer_3d_nozzle,
                    color: themeData.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'pages.dashboard.general.print_card.reprint',
                    style: TextStyle(color: themeData.colorScheme.primary),
                  ).tr(),
                ],
              ),
            ),
          ],
          child: TextButton.icon(
            style: model.klippyCanReceiveCommands
                ? TextButton.styleFrom(
                    disabledForegroundColor: themeData.colorScheme.primary,
                  )
                : null,
            onPressed: null,
            icon: const Icon(Icons.more_vert),
            label: const Text('pages.dashboard.general.move_card.more_btn').tr(),
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _KlippyStateActionButtons extends ConsumerWidget {
  const _KlippyStateActionButtons({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_machineStatusCardControllerProvider(machineUUID).notifier);
    var klippyState =
        ref.watch(_machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.klipperState));

    var klippyConnected =
        ref.watch(_machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.klippyConnected));
    var buttons = <Widget>[
      if ((const {KlipperState.shutdown, KlipperState.error, KlipperState.disconnected}.contains(klippyState)))
        ElevatedButton(
          onPressed: controller.restartKlipper,
          child: const Text('pages.dashboard.general.restart_klipper').tr(),
        ),
      if (klippyConnected && (const {KlipperState.shutdown, KlipperState.error}.contains(klippyState)))
        ElevatedButton(
          onPressed: controller.restartMCU,
          child: const Text('pages.dashboard.general.restart_mcu').tr(),
        ),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();
    var themeData = Theme.of(context);

    return ElevatedButtonTheme(
      data: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeData.colorScheme.error,
          foregroundColor: themeData.colorScheme.onError,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: buttons,
      ),
    );
  }
}

class _M117Message extends ConsumerWidget {
  const _M117Message({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_machineStatusCardControllerProvider(machineUUID).notifier);
    var m117 = ref.watch(_machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.m117));

    //TOOD: Animate this. So just use a AnimatedSwitcher and a size

    var themeData = Theme.of(context);

    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      transitionBuilder: (child, animation) => SizeAndFadeTransition(
        sizeAndFadeFactor: animation,
        child: child,
      ),
      child: (m117 == null)
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('M117', style: themeData.textTheme.titleSmall),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(m117, style: themeData.textTheme.bodySmall),
                    ),
                  ),
                  AsyncIconButton(
                    onPressed: controller.clearM117,
                    icon: Icon(Icons.clear, color: themeData.colorScheme.primary),
                    iconSize: 16,
                    tooltip: 'Clear M117',
                  ),
                ],
              ),
            ),
    );
  }
}

class _ExcludeObject extends ConsumerWidget {
  const _ExcludeObject({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    var controller = ref.watch(_machineStatusCardControllerProvider(machineUUID).notifier);
    var show = ref
        .watch(_machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.showExcludeObject));

    final Widget child;

    if (show) {
      var excludeObject =
          ref.watch(_machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.excludeObject));

      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(thickness: 1, height: 0),
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
            child: Row(
              children: [
                IconButton(
                  color: themeData.colorScheme.primary,
                  icon: LimitedBox(
                    maxHeight: 32,
                    maxWidth: 32,
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        const Icon(MaterialCommunityIcons.printer_3d_nozzle),
                        Positioned(
                          bottom: -0.6,
                          right: 1,
                          child: Icon(
                            Icons.circle,
                            size: 16,
                            color: themeData.colorScheme.onError,
                          ),
                        ),
                        Positioned(
                          bottom: -1,
                          right: 0,
                          child: Icon(
                            Icons.cancel,
                            size: 18,
                            color: themeData.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  tooltip: 'dialogs.exclude_object.title'.tr(),
                  onPressed: controller.excludeObject,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('pages.dashboard.general.print_card.current_object').tr(),
                      Text(
                        excludeObject?.currentObject ?? 'general.none'.tr(),
                        textAlign: TextAlign.center,
                        style: themeData.textTheme.bodyMedium?.copyWith(
                          color: themeData.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      child = const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      transitionBuilder: (child, animation) => SizeAndFadeTransition(
        sizeAndFadeFactor: animation,
        child: child,
      ),
      child: child,
    );
  }
}

/// The most recently printed files, offered while the printer is able to start a print.
class _PrintAgain extends ConsumerWidget {
  const _PrintAgain({super.key, required this.machineUUID});

  /// The min width a file needs, used to decide how many files fit.
  static const double _minTileWidth = 104;

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPrint = ref.watch(
      _machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.canStartPrint),
    );
    // The history is only requested once it is needed. A printer without the history component just shows nothing.
    final jobs = canPrint ? ref.watch(jobHistoryProvider(machineUUID, null)).value : null;

    final Widget child;
    if (jobs == null || jobs.every((job) => !job.exists)) {
      child = const SizedBox.shrink(key: Key('NoPrintAgain'));
    } else {
      final themeData = Theme.of(context);
      child = Column(
        key: const Key('PrintAgain'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(thickness: 1, height: 0),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'pages.dashboard.general.print_card.print_again',
                    style: themeData.textTheme.titleSmall,
                  ).tr(),
                ),
                TextButton(
                  onPressed: () => context.goNamed(AppRoute.history.name),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('pages.dashboard.general.print_card.history').tr(),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = (constraints.maxWidth / _minTileWidth).floor().clamp(1, 6);
                final recent = jobs.recentDistinct(max: count);

                return SizedBox(
                  height: 116,
                  child: Row(
                    children: [
                      for (final (i, job) in recent.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _RecentFile(key: ValueKey(job.filename), machineUUID: machineUUID, job: job),
                        ),
                      ],
                      // Keeps the size of the files, if there are less than fit.
                      for (var i = recent.length; i < min(count, 3); i++) ...[
                        const SizedBox(width: 8),
                        const Spacer(),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return AnimatedSizeAndFade(
      sizeDuration: kThemeAnimationDuration,
      fadeDuration: kThemeAnimationDuration,
      child: child,
    );
  }
}

class _RecentFile extends StatelessWidget {
  const _RecentFile({super.key, required this.machineUUID, required this.job});

  final String machineUUID;
  final HistoricalPrintJob job;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    // The time the slicer estimated tells more about a file than how long its last (maybe cancelled) job took.
    final duration = job.metadata.estimatedTime ?? job.printDuration;
    final subtitle = [?job.materials, if (duration >= 1) _shortDuration(duration)].join(' · ');
    final name = job.displayName;

    return Semantics(
      button: true,
      label: '${tr('pages.dashboard.general.print_card.print_again')}: $name',
      child: Material(
        color: themeData.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // The details show the file's settings, spool warnings and the button to start the print.
          onTap: () => context.pushNamed(
            AppRoute.fileManager_exlorer_gcodeDetail.name,
            pathParameters: {'path': job.metadata.parentPath},
            extra: job.metadata,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    // No hero: The same file might also be shown by another card or tab.
                    child: RemoteFileIcon(machineUUID: machineUUID, file: job.metadata, useHero: false),
                  ),
                ),
                const SizedBox(height: 6),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: themeData.textTheme.labelLarge),
                if (subtitle.isNotEmpty)
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: themeData.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `1h 28m`, `35m`, `45s`
  static String _shortDuration(double seconds) {
    final d = Duration(seconds: seconds.round());
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

@riverpod
class _MachineStatusCardController extends _$MachineStatusCardController {
  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  KlippyService get _klippyService => ref.read(klipperServiceProvider(machineUUID));

  @override
  FutureOr<_Model> build(String machineUUID) {
    ref.keepAliveFor();

    final klipperF = ref.watch(klipperProvider(machineUUID));
    final printerF = ref.watch(printerProvider(machineUUID));

    // Chaining asynchronous providers synchronously.
    final klipper = klipperF.requireValue;
    final printer = printerF.requireValue;

    return _Model(
      klippyConnected: klipper.klippyConnected,
      klippyStatusMessage: klipper.statusMessage,
      klipperState: klipper.klippyState,
      printState: printer.print.state,
      filename: printer.print.filename,
      message: printer.print.message,
      progress: printer.printProgress,
      m117: printer.displayStatus?.message,
      excludeObject: printer.excludeObject,
    );
  }

  void resetPrintState() => _printerService.resetPrintStat();

  void reprint() => _printerService.reprintCurrentFile();

  void restartKlipper() => _klippyService.restartKlipper();

  void restartMCU() => _klippyService.restartMCUs();

  Future<void> clearM117() async => await _printerService.m117();

  void excludeObject() => ref.read(dialogServiceProvider).show(DialogRequest(type: DialogType.excludeObject));
}

class _MachineStatusCardPreviewController extends _MachineStatusCardController {
  @override
  FutureOr<_Model> build(String machineUUID) {
    return const _Model(
      klippyConnected: true,
      klippyStatusMessage: 'Ready',
      klipperState: KlipperState.ready,
      printState: PrintState.standby,
      filename: 'Benchy.gcode',
      message: 'A Message',
      progress: 0.5,
      m117: 'M117 Message',
      excludeObject: null,
    );
  }

  @override
  Future<void> clearM117() async {
    state = state.whenData((value) => value.copyWith(m117: null));
  }

  @override
  // ignore: no-empty-block
  void excludeObject() {
    // Nothing to do here, as this is just a preview
  }

  @override
  // ignore: no-empty-block
  void reprint() {
    // Nothing to do here, as this is just a preview
  }

  @override
  // ignore: no-empty-block
  void resetPrintState() {
    // Nothing to do here, as this is just a preview
  }

  @override
  // ignore: no-empty-block
  void restartKlipper() {
    // Nothing to do here, as this is just a preview
  }

  @override
  // ignore: no-empty-block
  void restartMCU() {
    // Nothing to do here, as this is just a preview
  }
}

@freezed
sealed class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required bool klippyConnected,
    required String klippyStatusMessage,
    required KlipperState klipperState,
    required PrintState printState,
    required String filename,
    required String message,
    required double progress,
    String? m117,
    ExcludeObject? excludeObject,
  }) = __Model;

  bool get isPrintingOrPaused => printState == PrintState.printing || printState == PrintState.paused;

  bool get isCompleteOrCancelled => printState == PrintState.complete || printState == PrintState.cancelled;

  bool get showExcludeObject => klippyCanReceiveCommands && isPrintingOrPaused && excludeObject?.available == true;

  bool get showToolheadTable => klippyCanReceiveCommands && (isPrintingOrPaused || isCompleteOrCancelled);

  /// Whether a new print can be started: Klipper is ready and no print is active.
  bool get canStartPrint => klippyCanReceiveCommands && !isPrintingOrPaused;

  bool get klippyCanReceiveCommands => klipperState == KlipperState.ready && klippyConnected;
}
