/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/enums/eta_data_source.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/history_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/mobileraker_icons.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/time_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/overview/components/common/machine_cam_base_card.dart';
import 'package:mobileraker/ui/screens/overview/components/printer_card.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../routing/app_router.dart';
import 'common/progress_tracker.dart';
import 'common/state_chips.dart';

part 'printer_job_handler.freezed.dart';
part 'printer_job_handler.g.dart';

class PrinterJobHandler extends ConsumerWidget {
  const PrinterJobHandler({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding ${machine.logNameExtended}/PrinterCard/PrinterJobHandler');

    return AsyncGuard(
      debugLabel: '${machine.logNameExtended}/PrinterCard/ConnectionStateHandler',
      toGuard: _printerJobHandlerControllerProvider(machine).selectAs((d) => true),
      childOnData: _Body(machine: machine),
      childOnLoading: PrinterCard.loading(),
      childOnError: (e, s) =>
          MachineCamBaseCard(machine: machine, body: _PrinterProviderErrorBody(machine: machine, error: e, stack: s)),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printState = ref.watch(_printerJobHandlerControllerProvider(machine).selectRequireValue((d) => d.printState));
    final controller = ref.watch(_printerJobHandlerControllerProvider(machine).notifier);

    final body = switch (printState) {
      PrintState.complete || PrintState.cancelled => _JobCompleteCancelledBody(machine: machine),
      PrintState.printing || PrintState.paused => _JobPrintingPausedBody(machine: machine),
      PrintState.error => _JobErrorBody(machine: machine),
      PrintState.standby => _JobStandbyBody(machine: machine),
    };

    return MachineCamBaseCard(machine: machine, body: body, onTap: controller.openMachineDashboard);
  }
}

class _JobCompleteCancelledBody extends ConsumerWidget {
  const _JobCompleteCancelledBody({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _JobCompleteCancelledBody for ${machine.logName}');

    final (job, printState, totalDuration, hasWebcam, lastJob) = ref.watch(_printerJobHandlerControllerProvider(machine)
        .selectRequireValue((d) => (d.job, d.printState, d.totalDuration, d.hasWebcam, d.lastJob)));

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
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(machine.httpUri.host, style: themeData.textTheme.bodySmall),
                      Gap(4),
                      _JobText(job!),
                    ],
                  ),
                ),
                if (!hasWebcam) ...[Gap(4), PrintStateChip(printState: printState)],
              ],
            ),
          ],
        ),
        ProgressTracker(
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
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task_outlined,
                      size: themeData.textTheme.bodySmall?.fontSize,
                      color: themeData.textTheme.bodySmall?.color,
                    ),
                    Gap(4),
                    Text(
                      dateFormat(lastJob.endTime),
                      style: themeData.textTheme.bodySmall,
                    ),
                  ],
                )
              : null,
        ),
        _Actions(machine: machine),
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

    final (progress, job, hasWebcam, printState, eta) = ref.watch(_printerJobHandlerControllerProvider(machine)
        .selectRequireValue((d) => (d.progress, d.job, d.hasWebcam, d.printState, d.eta)));

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
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(machine.httpUri.host, style: themeData.textTheme.bodySmall),
                      Gap(4),
                      _JobText(job!),
                    ],
                  ),
                ),
                if (!hasWebcam) ...[Gap(4), PrintStateChip(printState: printState)],
              ],
            ),
          ],
        ),
        ProgressTracker(
          progress: progress,
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
                '@:pages.dashboard.general.print_card.eta: ${eta?.let(dateFormat) ?? '--:--'}',
                style: themeData.textTheme.bodySmall,
              ).tr(),
            ],
          ),
        ),
        _Actions(machine: machine),
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
    final (job, hasWebcam, eta, lastJob) = ref.watch(_printerJobHandlerControllerProvider(machine)
        .selectRequireValue((d) => (d.job, d.hasWebcam, d.eta, d.lastJob)));

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
                Flexible(child: Text('components.machine_card.waiting_for_job').tr()),
              ],
            ),
            if (!hasWebcam) PrintStateChip(printState: PrintState.standby),
          ],
        ),
        if (lastJob?.endTime != null) Text(lastActivity(lastJob!.endTime), style: themeData.textTheme.bodySmall),
        _Actions(machine: machine),
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
    final (message, job, hasWebcam) = ref.watch(
        _printerJobHandlerControllerProvider(machine).selectRequireValue((d) => (d.message, d.job, d.hasWebcam)));

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
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(machine.httpUri.host, style: themeData.textTheme.bodySmall),
                      Gap(4),
                      _JobText(job!),
                    ],
                  ),
                ),
                if (!hasWebcam) ...[Gap(4), PrintStateChip(printState: PrintState.error)],
              ],
            ),
          ],
        ),
        if (message != null) ...[
          Card(
            color: themeData.colorScheme.errorContainer,
            margin: EdgeInsets.zero,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                      padding: const EdgeInsets.all(4.0),
                      child:
                          Icon(MobilerakerIcons.nozzle_alert_outline, color: themeData.colorScheme.onErrorContainer)),
                  Gap(8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('components.machine_card.job_error_detected'),
                          style:
                              themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.onErrorContainer),
                        ),
                        Text(
                          message,
                          style: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.onErrorContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Gap(8),
        ],
        _Actions(machine: machine),
      ],
    );
  }
}

class _PrinterProviderErrorBody extends ConsumerWidget {
  const _PrinterProviderErrorBody({super.key, required this.machine, required this.error, required this.stack});

  final Machine machine;

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    Color? onColor = themeData.colorScheme.onErrorContainer;
    Color? bgColor = themeData.colorScheme.errorContainer;
    IconData icon = Icons.running_with_errors;

    String? message;
    var e = error;
    if (e is MobilerakerException) {
      // title = e.message;
      if (e.parentException != null) {
        message = e.parentException.toString();
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap(8),
        Text(machine.httpUri.host, style: themeData.textTheme.bodySmall),
        Gap(8),
        Card(
          color: bgColor,
          shape: _border(context, onColor),
          margin: EdgeInsets.zero,
          elevation: 0,
          child: InkWell(
            onTap: () {
              ref.read(dialogServiceProvider).show(DialogRequest(
                  type: CommonDialogs.stacktrace,
                  title: 'Error fetching Printer Data',
                  body: 'Exception:\n $error\n\n$stack'));
            },
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
                          tr('Error while fetching Printer Data'),
                          style: themeData.textTheme.bodyMedium?.copyWith(color: onColor),
                        ),
                        if (message != null)
                          Text(
                            message,
                            style: themeData.textTheme.bodySmall?.copyWith(color: onColor),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Gap(8),
        _Actions(machine: machine),
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

class _Actions extends ConsumerWidget {
  const _Actions({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _ActionsWidget for ${machine.logName}');
    final printState =
        ref.watch(_printerJobHandlerControllerProvider(machine).select((d) => d.valueOrNull?.printState));
    final controller = ref.watch(_printerJobHandlerControllerProvider(machine).notifier);

    final themeData = Theme.of(context);
    final isLight = themeData.brightness == Brightness.light;

    final buttons = <Widget>[];

    switch (printState) {
      case PrintState.printing: // Checked
        buttons.add(ElevatedButton.icon(
          onPressed: controller.pauseJob,
          label: Text('general.pause').tr(),
          icon: Icon(Icons.pause_outlined),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.extension<CustomColors>()?.warning,
            foregroundColor: themeData.extension<CustomColors>()?.onWarning,
          ),
        ));
        buttons.add(ElevatedButton(
          onPressed: controller.emergencyStop,
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: isLight ? themeData.colorScheme.error : themeData.colorScheme.errorContainer,
            foregroundColor: isLight ? themeData.colorScheme.onError : themeData.colorScheme.onErrorContainer,
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
      case null:
        buttons.add(ElevatedButton.icon(
          onPressed: () => ref.invalidate(printerServiceProvider(machine.uuid)),
          label: Text('general.retry').tr(),
          icon: Icon(Icons.restart_alt),
          style: ElevatedButton.styleFrom(
            iconSize: 18,
            backgroundColor: themeData.extension<CustomColors>()?.warning,
            foregroundColor: themeData.extension<CustomColors>()?.onWarning,
            iconColor: themeData.extension<CustomColors>()?.onWarning,
          ),
        ));
        break;
    }

    return Row(
      spacing: 6,
      children: [
        for (var button in buttons) Expanded(child: button),
        if (printState != null)
          IconButton(
            onPressed: controller.openMachineDashboard,
            icon: Icon(Icons.keyboard_arrow_right_outlined),
          ),
      ],
    );
  }
}

class _JobText extends StatelessWidget {
  const _JobText(this.job, {super.key});

  final String job;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(FlutterIcons.file_outline_mco, size: 14),
        Gap(4),
        Flexible(
          child: Tooltip(
            message: job,
            child: Text(job, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

@riverpod
class _PrinterJobHandlerController extends _$PrinterJobHandlerController {
  SelectedMachineService get _selectedMachineService => ref.read(selectedMachineServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machine.uuid));

  KlippyService get _klippyService => ref.read(klipperServiceProvider(machine.uuid));

  GoRouter get _goRouter => ref.read(goRouterProvider);

  _Model? _lastUpdate;

  @override
  FutureOr<_Model> build(Machine machine) async {
    final etaSourceSettings = ref
        .watch(listSettingProvider(AppSettingKeys.etaSources,
            AppSettingKeys.etaSources.defaultValue as List<ETADataSource>, ETADataSource.fromJson))
        .cast<ETADataSource>()
        .toSet();
    final hasWebcam =
        ref.watch(activeWebcamInfoForMachineProvider(machine.uuid).select((d) => d.hasValue && d.value != null));

    final lastJobFuture = ref.watch(lastJobProvider(machine.uuid).future).onError((_, __) => null);
    final printerDataFuture = ref.watch(printerProvider(machine.uuid).selectAsync((d) {
      return (
        d.print.state,
        d.printProgress,
        d.print.filename.unless(d.print.filename.isEmpty),
        d.calcEta(etaSourceSettings),
        d.calcRemainingTimeAvg(etaSourceSettings),
        d.print.totalDuration,
        d.print.message.unless(d.print.message.isEmpty),
      );
    }));
    final (lastJob, (printState, progress, job, eta, remaining, totalDuration, message)) =
        await (lastJobFuture, printerDataFuture).wait;

    return _Model(
      printState: printState,
      progress: progress,
      job: job,
      eta: eta,
      remaining: remaining,
      totalDuration: totalDuration,
      message: message,
      lastJob: lastJob,
      hasWebcam: hasWebcam,
    );
  }

  @override
  bool updateShouldNotify(AsyncValue<_Model> previous, AsyncValue<_Model> next) {
    // For doubles we use epsilon comparison to avoid updating to often even if the value is jsut changed very slightly
    final progressIsEpsilonEqual = _lastUpdate?.progress.closeTo(next.valueOrNull?.progress ?? 0, 0.01) == true;
    final durationIsEpsilonEqual = _lastUpdate?.totalDuration?.closeTo(next.valueOrNull?.totalDuration ?? 0, 1) == true;

    // For the eta we check if the difference is less than 2s to evaluate if the eta is the same
    final etaIsEpsilonEqual = _lastUpdate?.eta == next.valueOrNull?.eta ||
        _lastUpdate?.eta != null &&
            next.valueOrNull?.eta != null &&
            _lastUpdate!.eta!.difference(next.value!.eta!).abs().inSeconds < 2;

    // For remaining we also have 2 seconds epsilon
    final remainingIsEpsilonEqual = _lastUpdate?.remaining == next.valueOrNull?.remaining ||
        _lastUpdate?.remaining != null &&
            next.valueOrNull?.remaining != null &&
            (_lastUpdate!.remaining! - next.value!.remaining!).abs() < 2;

    var shouldN = !progressIsEpsilonEqual ||
        _lastUpdate?.printState != next.valueOrNull?.printState ||
        _lastUpdate?.job != next.valueOrNull?.job ||
        !etaIsEpsilonEqual ||
        !durationIsEpsilonEqual ||
        !remainingIsEpsilonEqual ||
        _lastUpdate?.message != next.valueOrNull?.message ||
        _lastUpdate?.lastJob != next.valueOrNull?.lastJob;

    if (shouldN) {
      // talker.info('UpdateShouldNotify: $shouldN');
      // talker.info('progress: ${_lastUpdate?.progress} vs ${next.value?.progress} Trig: ${!progressIsEpsilonEqual}');
      // talker.info(
      //     'printState: ${_lastUpdate?.printState} vs ${next.value?.printState} Trig: ${_lastUpdate?.printState != next.valueOrNull?.printState}');
      // talker.info(
      //     'TotalDur: ${_lastUpdate?.totalDuration} vs ${next.value?.totalDuration} Trig: ${!durationIsEpsilonEqual}');
      // talker.info(
      //     'Remaining: ${_lastUpdate?.remaining} vs ${next.value?.remaining} Trig: ${!remainingIsEpsilonEqual}');
      // talker.info(
      //     'eta: ${_lastUpdate?.eta} vs ${next.value?.eta} Trig: ${!etaIsEpsilonEqual}');
      // talker.info(
      //     'job: ${_lastUpdate?.job} vs ${next.value?.job} Trig: ${_lastUpdate?.job != next.valueOrNull?.job}');
      // talker.info(
      //     'message: ${_lastUpdate?.message} vs ${next.value?.message} Trig: ${_lastUpdate?.message != next.valueOrNull?.message}');
      // talker.info(
      //     'lastJob: ${_lastUpdate?.lastJob} vs ${next.value?.lastJob} Trig: ${_lastUpdate?.lastJob != next.valueOrNull?.lastJob}');
      _lastUpdate = next.value;
    }

    return shouldN;
  }

  void openMachineDashboard() {
    _selectedMachineService.selectMachine(machine);
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
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required PrintState printState,
    required double progress,
    String? job,
    double? totalDuration,
    int? remaining,
    DateTime? eta,
    String? message,
    HistoricalPrintJob? lastJob,
    required bool hasWebcam,
  }) = __Model;
}
