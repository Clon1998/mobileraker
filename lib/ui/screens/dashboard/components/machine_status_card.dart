/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/animation/SizeAndFadeTransition.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/skeletons/card_title_skeleton.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/klippy_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../service/ui/dialog_service_impl.dart';
import 'toolhead_info/toolhead_info_table.dart';

part 'machine_status_card.freezed.dart';
part 'machine_status_card.g.dart';

class MachineStatusCard extends ConsumerWidget {
  const MachineStatusCard({super.key, required this.machineUUID});

  factory MachineStatusCard.preview() {
    return const _MachineStatusCardPreview();
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('Rebuilding MachineStatusCard for $machineUUID');

    var showLoading = ref.watch(_machineStatusCardControllerProvider(machineUUID).select((value) => value.isLoadingOrRefreshWithError));

    if (showLoading) return const _MachineStatusCardLoading();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CardTitle(machineUUID: machineUUID),
          _KlippyStateActionButtons(machineUUID: machineUUID),
          _M117Message(machineUUID: machineUUID),
          _ExcludeObject(machineUUID: machineUUID),
          Consumer(builder: (ctx, iref, _) {
            var model = iref.watch(
                _machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.showToolheadTable));
            // logger.i('Rebuilding ToolheadInfoTable for $machineUUID');
            return AnimatedSwitcher(
              duration: kThemeAnimationDuration,
              transitionBuilder: (child, animation) => SizeAndFadeTransition(
                sizeAndFadeFactor: animation,
                child: child,
              ),
              child: model
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(thickness: 1, height: 0),
                        ToolheadInfoTable(machineUUID: machineUUID),
                      ],
                    )
                  : const SizedBox.shrink(),
            );
          }),
        ],
      ),
    );
  }
}

class _MachineStatusCardPreview extends MachineStatusCard {
  static const String _machineUUID = 'preview';

  const _MachineStatusCardPreview({super.key}) : super(machineUUID: _machineUUID);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        _machineStatusCardControllerProvider(_machineUUID).overrideWith(_MachineStatusCardPreviewController.new),
      ],
      child: Consumer(
        builder: (innerContext, innerRef, _) => super.build(innerContext, innerRef),
      ),
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

    // logger.i('Rebuilding _CardTitle for $machineUUID');

    var printState =
        ref.watch(_machineStatusCardControllerProvider(machineUUID).selectRequireValue((data) => data.printState));
    return ListTile(
      contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
      leading: Icon(klippyCanReceiveCommands ? FlutterIcons.monitor_dashboard_mco : FlutterIcons.disconnect_ant),
      title: _Title(machineUUID: machineUUID),
      subtitle: switch (printState) {
        PrintState.printing ||
        PrintState.paused => Text(
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

    // logger.i('Rebuilding _Title for $machineUUID');

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

    // logger.i('Rebuilding _Trailing for $machineUUID');

    var themeData = Theme.of(context);

    return switch (model.printState) {
      PrintState.printing => CircularPercentIndicator(
          radius: 25,
          lineWidth: 4,
          percent: model.progress,
          center: Text(NumberFormat.percentPattern(context.locale.toStringWithSeparator()).format(model.progress)),
          progressColor: (model.printState == PrintState.complete) ? Colors.green : Colors.deepOrange,
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
                    FlutterIcons.printer_3d_nozzle_mco,
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
    // logger.i('Rebuilding _KlippyStateActionButtons for $machineUUID');
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
    // logger.i('Rebuilding _M117Message for $machineUUID');
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
    // logger.i('Rebuilding _ExcludeObject for $machineUUID');

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
                        const Icon(FlutterIcons.printer_3d_nozzle_mco),
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

@riverpod
class _MachineStatusCardController extends _$MachineStatusCardController {
  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  KlippyService get _klippyService => ref.read(klipperServiceProvider(machineUUID));

  @override
  Stream<_Model> build(String machineUUID) async* {
    ref.keepAliveFor();
    // await Future.delayed(const Duration(seconds: 5));
    // logger.i('Building content for MachineStatusCard for $machineUUID');
    var printerProviderr = printerProvider(machineUUID);
    var klipperProviderr = klipperProvider(machineUUID);

    var printer = ref.watchAsSubject(printerProviderr);
    var klipper = ref.watchAsSubject(klipperProviderr);

    yield* Rx.combineLatest2(
      printer,
      klipper,
      (a, b) => _Model(
        klippyConnected: b.klippyConnected,
        klippyStatusMessage: b.statusMessage,
        klipperState: b.klippyState,
        printState: a.print.state,
        filename: a.print.filename,
        message: a.print.message,
        progress: a.printProgress,
        m117: a.displayStatus?.message,
        excludeObject: a.excludeObject,
      ),
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
  Stream<_Model> build(String machineUUID) {
    return Stream.value(const _Model(
      klippyConnected: true,
      klippyStatusMessage: 'Ready',
      klipperState: KlipperState.ready,
      printState: PrintState.standby,
      filename: 'Benchy.gcode',
      message: 'A Message',
      progress: 0.5,
      m117: 'M117 Message',
      excludeObject: null,
    ));
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
class _Model with _$Model {
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

  bool get showExcludeObject => klippyCanReceiveCommands && isPrintingOrPaused && excludeObject?.available == true;

  bool get showToolheadTable => klippyCanReceiveCommands && isPrintingOrPaused;

  bool get klippyCanReceiveCommands => klipperState == KlipperState.ready && klippyConnected;
}
