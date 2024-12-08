/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/time_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/dashboard/components/toolhead_info/toolhead_info_table_controller.dart';
import 'package:mobileraker/util/extensions/datetime_extension.dart';
import 'package:shimmer/shimmer.dart';

class ToolheadInfoTable extends ConsumerWidget {
  static const String POS_ROW = 'p';
  static const String MOV_ROW = 'm';
  static const String SUMMARY_ROW = 's';

  final List<String> rowsToShow;

  const ToolheadInfoTable({
    super.key,
    required this.machineUUID,
    this.rowsToShow = const [POS_ROW, MOV_ROW],
  });

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ToolheadData(machineUUID: machineUUID, rowsToShow: rowsToShow);
  }
}

class _ToolheadData extends ConsumerWidget {
  const _ToolheadData({
    super.key,
    required this.machineUUID,
    required this.rowsToShow,
  });

  final String machineUUID;
  final List<String> rowsToShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('Rebuilding ToolheadInfoTable');

    var dateFormat = ref.watch(dateFormatServiceProvider).Hm();

    var numFormatFixed1 =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);
    var numFormatFixed2 =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 2);

    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(
          width: 1,
          color: Theme.of(context).dividerColor,
          style: BorderStyle.solid,
        ),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {0: FractionColumnWidth(.1)},
      children: [
        if (rowsToShow.contains(ToolheadInfoTable.SUMMARY_ROW))
          TableRow(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.history_toggle_off),
              ),
              _ConsumerCell(
                label: tr('pages.dashboard.general.print_card.print_time'),
                consumerListenable:
                    toolheadInfoProvider(machineUUID).selectAs((value) => secondsToDurationText(value.totalDuration)),
              ),
              _ConsumerCell(
                label: tr('pages.dashboard.general.print_card.filament'),
                consumerListenable: toolheadInfoProvider(machineUUID)
                    .selectAs((value) => '${value.usedFilament?.let(numFormatFixed1.format) ?? 0} m'),
              ),
            ],
          ),
        if (rowsToShow.contains(ToolheadInfoTable.POS_ROW))
          TableRow(children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(FlutterIcons.axis_arrow_mco),
            ),
            _ConsumerCell(
              label: 'X',
              consumerListenable: toolheadInfoProvider(machineUUID)
                  .selectAs((value) => value.postion.elementAtOrNull(0)?.let(numFormatFixed2.format) ?? '--'),
            ),
            _ConsumerCell(
              label: 'Y',
              consumerListenable: toolheadInfoProvider(machineUUID)
                  .selectAs((value) => value.postion.elementAtOrNull(1)?.let(numFormatFixed2.format) ?? '--'),
            ),
            _ConsumerCell(
              label: 'Z',
              consumerListenable: toolheadInfoProvider(machineUUID)
                  .selectAs((value) => value.postion.elementAtOrNull(2)?.let(numFormatFixed2.format) ?? '--'),
            ),
          ]),
        if (rowsToShow.contains(ToolheadInfoTable.MOV_ROW)) ...[
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(FlutterIcons.layers_fea),
              ),
              _ConsumerCell(
                label: tr('pages.dashboard.general.print_card.speed'),
                consumerListenable: toolheadInfoProvider(machineUUID).selectAs((value) => '${value.mmSpeed} mm/s'),
              ),
              _ConsumerCell(
                label: tr('pages.dashboard.general.print_card.layer'),
                consumerListenable:
                    toolheadInfoProvider(machineUUID).selectAs((value) => '${value.currentLayer}/${value.maxLayers}'),
              ),
              _ConsumerCell(
                label: tr('pages.dashboard.general.print_card.elapsed'),
                consumerListenable:
                    toolheadInfoProvider(machineUUID).selectAs((value) => secondsToDurationText(value.totalDuration)),
              ),
            ],
          ),
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(FlutterIcons.printer_3d_mco),
              ),
              _ConsumerCell(
                label: tr('pages.dashboard.general.print_card.flow'),
                consumerListenable:
                    toolheadInfoProvider(machineUUID).selectAs((value) => '${value.currentFlow ?? 0} mm³/s'),
              ),
              _ConsumerTooltipCell(
                consumerTooltipListenable: toolheadInfoProvider(machineUUID).selectAs((value) => tr(
                      'pages.dashboard.general.print_card.filament_tooltip',
                      args: [
                        value.usedFilamentPerc.toStringAsFixed(0),
                        value.usedFilament?.let(numFormatFixed1.format) ?? '0',
                        value.totalFilament?.let(numFormatFixed1.format) ?? '-',
                      ],
                    )),
                child: _ConsumerCell(
                  label: tr('pages.dashboard.general.print_card.filament'),
                  consumerListenable: toolheadInfoProvider(machineUUID)
                      .selectAs((value) => '${value.usedFilament?.let(numFormatFixed1.format) ?? 0} m'),
                ),
              ),
              _ConsumerTooltipCell(
                consumerTooltipListenable: toolheadInfoProvider(machineUUID).selectAs((value) => tr(
                      'pages.dashboard.general.print_card.eta_tooltip',
                      namedArgs: {
                        'avg': value.remaining?.let(secondsToDurationText) ?? '--',
                        'slicer': value.remainingSlicer?.let(secondsToDurationText) ?? '--',
                        'file': value.remainingFile?.let(secondsToDurationText) ?? '--',
                        'filament': value.remainingFilament?.let(secondsToDurationText) ?? '--',
                      },
                    )),
                child: Consumer(
                  builder: (context, ref, child) {
                    var asyncValue = ref.watch(toolheadInfoProvider(machineUUID).selectAs((value) {
                      var eta = value.eta;

                      if (eta == null) return ('--:--', null);
                      var format = dateFormat.format(eta);
                      int? inDays = null;
                      if (eta.isNotToday()) {
                        // Add 1 day as the difference requires 24 hours to be a day
                        // 1.1.2024 23:59 - 2.1.2024 04:00 = 0 days -> still next day -> +1 to show eta at 04:00 + 1 day
                        inDays = eta.difference(DateTime.now()).inDays + 1;
                      }
                      return (format, inDays);
                    }));

                    return switch (asyncValue) {
                      AsyncValue(isLoading: true, isReloading: false) => const _LoadingCell(),
                      AsyncData(value: (String eta, int? days)) => Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              child!,
                              AutoSizeText.rich(
                                TextSpan(
                                  text: eta,
                                  children: [
                                    if (days != null && days > 0)
                                      TextSpan(
                                        text: '+$days',
                                        style: TextStyle(fontFeatures: [FontFeature.superscripts()]),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                stepGranularity: 0.1,
                                minFontSize: 10,
                              ),
                              // Text(asyncValue.requireValue),
                            ],
                          ),
                        ),
                      _ => const Text('ERR'),
                    };
                  },
                  child: AutoSizeText(
                    tr('pages.dashboard.general.print_card.eta'),
                    maxLines: 1,
                    stepGranularity: 0.1,
                    minFontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ConsumerCell extends StatelessWidget {
  const _ConsumerCell({super.key, required this.label, required this.consumerListenable});

  final String label;
  final ProviderListenable<AsyncValue<String>> consumerListenable;

  @override
  Widget build(_) => Consumer(
        builder: (context, ref, child) {
          var asyncValue = ref.watch(consumerListenable);

          return switch (asyncValue) {
            AsyncValue(isLoading: true, isReloading: false) => const _LoadingCell(),
            AsyncData(value: var data) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    child!,
                    AutoSizeText(
                      data,
                      maxLines: 1,
                      stepGranularity: 0.1,
                      minFontSize: 10,
                    ),
                    // Text(asyncValue.requireValue),
                  ],
                ),
              ),
            _ => const Text('ERR'),
          };
        },
        child: AutoSizeText(
          label,
          maxLines: 1,
          stepGranularity: 0.1,
          minFontSize: 10,
        ),
      );
}

class _LoadingCell extends StatelessWidget {
  const _LoadingCell({super.key});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);

    return Shimmer.fromColors(
      baseColor: Colors.grey,
      highlightColor: themeData.colorScheme.background,
      child: const Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 17,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white),
              ),
            ),
            SizedBox(height: 4),
            SizedBox(
              width: 44,
              height: 17,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsumerTooltipCell extends StatelessWidget {
  const _ConsumerTooltipCell({
    super.key,
    required this.child,
    required this.consumerTooltipListenable,
  });

  final ProviderListenable<AsyncValue<String>> consumerTooltipListenable;
  final Widget child;

  @override
  Widget build(_) => Consumer(
        builder: (context, ref, innerChild) {
          var asyncTooltipValue = ref.watch(consumerTooltipListenable);

          if (asyncTooltipValue.isLoading && !asyncTooltipValue.isReloading) return child!;

          return Tooltip(
            margin: const EdgeInsets.all(8.0),
            textAlign: TextAlign.center,
            message: asyncTooltipValue.requireValue,
            child: innerChild!,
          );
        },
        child: child,
      );
}
