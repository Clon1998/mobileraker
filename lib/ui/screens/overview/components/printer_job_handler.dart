/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/enums/eta_data_source.dart';
import 'package:common/data/model/hive/machine.dart';
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
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/date_time_extension.dart';
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
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printState = ref.watch(_printerJobHandlerControllerProvider(machine).selectRequireValue((d) => d.printState));

    final body = switch (printState) {
      PrintState.complete || PrintState.cancelled => _JobCompleteCancelledBody(machine: machine),
      PrintState.printing || PrintState.paused => _JobPrintingPausedBody(machine: machine),
      PrintState.error => _JobErrorBody(machine: machine),
      PrintState.standby => _JobStandbyBody(machine: machine),
    };

    return MachineCamBaseCard(machine: machine, body: body);
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
                if (!hasWebcam) PrintStateChip(printState: printState),
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

    final (progress, job, hasWebcam, printState, eta) = ref.watch(_printerJobHandlerControllerProvider(machine)
        .selectRequireValue((d) => (d.progress, d.job, d.hasWebcam, d.printState, d.eta)));

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
                if (!hasWebcam) PrintStateChip(printState: printState),
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
                Text('components.machine_card.waiting_for_job').tr(),
              ],
            ),
            if (!hasWebcam) PrintStateChip(printState: PrintState.standby),
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
                if (!hasWebcam) PrintStateChip(printState: PrintState.error),
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
              child: Text(
                message,
                style: themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.onErrorContainer),
              ),
            ),
          ),
          Gap(8),
        ],
        _ActionsWidget(machine: machine),
      ],
    );
  }
}

class _ActionsWidget extends ConsumerWidget {
  const _ActionsWidget({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding _ActionsWidget for ${machine.logName}');
    final printState = ref.watch(_printerJobHandlerControllerProvider(machine).selectRequireValue((d) => d.printState));
    final controller = ref.watch(_printerJobHandlerControllerProvider(machine).notifier);

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
            backgroundColor: themeData.extension<CustomColors>()?.warning,
            foregroundColor: themeData.extension<CustomColors>()?.onWarning,
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
class _PrinterJobHandlerController extends _$PrinterJobHandlerController {
  SelectedMachineService get _selectedMachineService => ref.read(selectedMachineServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  PrinterService get _printerService => ref.read(printerServiceProvider(machine.uuid));

  KlippyService get _klippyService => ref.read(klipperServiceProvider(machine.uuid));

  GoRouter get _goRouter => ref.read(goRouterProvider);

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
    final result = await Future.wait([lastJobFuture, printerDataFuture]);

    final lastJob = result[0] as HistoricalPrintJob?;
    final (printState, progress, job, eta, remaining, totalDuration, message) =
        result[1] as (PrintState, double, String?, DateTime?, int?, double?, String?);

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
    final wasLoading = previous.isLoading;
    final isLoading = next.isLoading;

    final loadingTransition = (wasLoading || isLoading) && wasLoading != isLoading;
    final progressEpsilon = previous.valueOrNull?.progress?.closeTo(next.valueOrNull?.progress ?? 0, 0.01) != false;

    return loadingTransition && progressEpsilon ||
        previous.valueOrNull?.printState != next.valueOrNull?.printState ||
        previous.valueOrNull?.job != next.valueOrNull?.job ||
        previous.valueOrNull?.remaining != next.valueOrNull?.remaining ||
        previous.valueOrNull?.eta != next.valueOrNull?.eta ||
        previous.valueOrNull?.totalDuration != next.valueOrNull?.totalDuration ||
        previous.valueOrNull?.message != next.valueOrNull?.message ||
        previous.valueOrNull?.lastJob != next.valueOrNull?.lastJob;
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
