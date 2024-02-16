/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/klippy_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../tabs/general_tab_controller.dart';
import 'toolhead_info/toolhead_info_table.dart';

class PrintCard extends ConsumerWidget {
  const PrintCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    KlipperInstance klippyInstance =
        ref.watch(generalTabViewControllerProvider.select((data) => data.value!.klippyData));

    var machineUUID = ref.watch(generalTabViewControllerProvider.select((data) => data.value!.machine.uuid));

    bool isPrintingOrPaused = ref.watch(generalTabViewControllerProvider.select((data) {
      var printState = data.value!.printerData.print.state;

      return printState == PrintState.printing || printState == PrintState.paused;
    }));

    ExcludeObject? excludeObject =
        ref.watch(generalTabViewControllerProvider.select((data) => data.value!.printerData.excludeObject));

    var themeData = Theme.of(context);
    var klippyCanReceiveCommands = klippyInstance.klippyCanReceiveCommands;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
            leading: Icon(klippyCanReceiveCommands ? FlutterIcons.monitor_dashboard_mco : FlutterIcons.disconnect_ant),
            title: Text(
              klippyCanReceiveCommands
                  ? ref.watch(generalTabViewControllerProvider.select(
                      (data) => data.value!.printerData.print.stateName,
                    ))
                  : klippyInstance.statusMessage,
              style: TextStyle(
                color: !klippyCanReceiveCommands ? themeData.colorScheme.error : null,
              ),
            ),
            subtitle: _subTitle(ref),
            trailing: _trailing(context, ref, themeData, klippyCanReceiveCommands),
          ),
          const _KlippyStateActionButtons(),
          const _M117Message(),
          if (klippyCanReceiveCommands && isPrintingOrPaused && excludeObject != null && excludeObject.available) ...[
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
                    onPressed: ref.read(generalTabViewControllerProvider.notifier).onExcludeObjectPressed,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'pages.dashboard.general.print_card.current_object',
                        ).tr(),
                        Text(
                          excludeObject.currentObject ?? 'general.none'.tr(),
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
          if (klippyCanReceiveCommands && isPrintingOrPaused) ...[
            const Divider(thickness: 1, height: 0),
            ToolheadInfoTable(machineUUID: machineUUID),
          ],
        ],
      ),
    );
  }

  Widget? _trailing(
    BuildContext context,
    WidgetRef ref,
    ThemeData themeData,
    bool klippyCanReceiveCommands,
  ) {
    PrintState printState =
        ref.watch(generalTabViewControllerProvider.select((data) => data.value!.printerData.print.state));

    var progress = ref.watch(generalTabViewControllerProvider.select((data) => data.value!.printerData.printProgress));

    switch (printState) {
      case PrintState.printing:
        return CircularPercentIndicator(
          radius: 25,
          lineWidth: 4,
          percent: progress,
          center: Text(NumberFormat.percentPattern(context.locale.toStringWithSeparator()).format(progress)),
          progressColor: (printState == PrintState.complete) ? Colors.green : Colors.deepOrange,
        );
      case PrintState.complete:
      case PrintState.cancelled:
        return PopupMenuButton(
          enabled: klippyCanReceiveCommands,
          padding: EdgeInsets.zero,
          position: PopupMenuPosition.over,
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              enabled: klippyCanReceiveCommands,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onTap: ref.read(generalTabViewControllerProvider.notifier).onResetPrintTap,
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
              enabled: klippyCanReceiveCommands,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onTap: ref.read(generalTabViewControllerProvider.notifier).onReprintTap,
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
            style: klippyCanReceiveCommands
                ? TextButton.styleFrom(
                    disabledForegroundColor: themeData.colorScheme.primary,
                  )
                : null,
            onPressed: null,
            icon: const Icon(Icons.more_vert),
            label: const Text('pages.dashboard.general.move_card.more_btn').tr(),
          ),
        );
      default:
        return null;
    }
  }

  Widget? _subTitle(WidgetRef ref) {
    var print = ref.watch(generalTabViewControllerProvider.select((data) => data.value!.printerData.print));

    switch (print.state) {
      case PrintState.paused:
      case PrintState.printing:
        return Text(print.filename);
      case PrintState.error:
        return Text(print.message);
      default:
        return null;
    }
  }
}

class _KlippyStateActionButtons extends ConsumerWidget {
  const _KlippyStateActionButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(generalTabViewControllerProvider.notifier);
    var model =
        ref.watch(generalTabViewControllerProvider.selectAs((data) => data.klippyData.klippyState)).requireValue;

    var buttons = <Widget>[
      if ((const {KlipperState.shutdown, KlipperState.error, KlipperState.disconnected}.contains(model)))
        ElevatedButton(
          onPressed: controller.onRestartKlipperPressed,
          child: const Text('pages.dashboard.general.restart_klipper').tr(),
        ),
      if ((const {KlipperState.shutdown, KlipperState.error}.contains(model)))
        ElevatedButton(
          onPressed: controller.onRestartMCUPressed,
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
  const _M117Message({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var m117 = ref.watch(generalTabViewControllerProvider.selectAs((data) => data.printerData.displayStatus?.message));
    if (m117.valueOrNull == null) return const SizedBox.shrink();

    var themeData = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('M117', style: themeData.textTheme.titleSmall),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                m117.valueOrNull.toString(),
                style: themeData.textTheme.bodySmall,
              ),
            ),
          ),
          IconButton(
            onPressed: ref.read(generalTabViewControllerProvider.notifier).onClearM117,
            icon: const Icon(Icons.clear),
            iconSize: 16,
            color: themeData.colorScheme.primary,
            tooltip: "Clear M117",
          ),
        ],
      ),
    );
  }
}
