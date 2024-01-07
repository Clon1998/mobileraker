/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/time_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/date_format_service.dart';
import 'package:mobileraker/ui/screens/dashboard/components/toolhead_info/toolhead_info_table_controller.dart';
import 'package:shimmer/shimmer.dart';

class ToolheadInfoTable extends ConsumerWidget {
  static const String POS_ROW = "p";
  static const String MOV_ROW = "m";

  final List<String> rowsToShow;

  const ToolheadInfoTable({
    Key? key,
    required this.machineUUID,
    this.rowsToShow = const [POS_ROW, MOV_ROW],
  }) : super(key: key);

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ToolheadData(machineUUID: machineUUID, rowsToShow: rowsToShow);
  }
}

class _ToolheadData extends ConsumerWidget {
  const _ToolheadData({
    Key? key,
    required this.machineUUID,
    required this.rowsToShow,
  }) : super(key: key);

  final String machineUUID;
  final List<String> rowsToShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isPrintingOrPaused =
        ref.watch(toolheadInfoProvider(machineUUID).selectAs((data) => data.printingOrPaused)).valueOrNull == true;
    var dateFormat = ref.watch(dateFormatServiceProvider).Hm();

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
        if (rowsToShow.contains(ToolheadInfoTable.POS_ROW))
          TableRow(children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(FlutterIcons.axis_arrow_mco),
            ),
            _ConsumerCell(
              label: 'X',
              consumerListenable: toolheadInfoProvider(machineUUID)
                  .selectAs((value) => value.postion.elementAtOrNull(0)?.toStringAsFixed(2) ?? '--'),
            ),
            _ConsumerCell(
              label: 'Y',
              consumerListenable: toolheadInfoProvider(machineUUID)
                  .selectAs((value) => value.postion.elementAtOrNull(1)?.toStringAsFixed(2) ?? '--'),
            ),
            _ConsumerCell(
              label: 'Z',
              consumerListenable: toolheadInfoProvider(machineUUID)
                  .selectAs((value) => value.postion.elementAtOrNull(2)?.toStringAsFixed(2) ?? '--'),
            ),
          ]),
        if (rowsToShow.contains(ToolheadInfoTable.MOV_ROW) && isPrintingOrPaused) ...[
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
                label: tr('pages.dashboard.general.print_card.filament'),
                consumerListenable: toolheadInfoProvider(machineUUID)
                    .selectAs((value) => '${value.usedFilament?.toStringAsFixed(1) ?? 0} m'),
                consumerTooltipListenable: toolheadInfoProvider(machineUUID).selectAs((value) => tr(
                      'pages.dashboard.general.print_card.filament_tooltip',
                      args: [
                        value.usedFilamentPerc.toStringAsFixed(0),
                        value.usedFilament?.toStringAsFixed(1) ?? '0',
                        value.totalFilament?.toStringAsFixed(1) ?? '-',
                      ],
                    )),
              ),
              _ConsumerTooltipCell(
                label: tr(
                  'pages.dashboard.general.print_card.eta',
                ),
                consumerListenable: toolheadInfoProvider(machineUUID)
                    .selectAs((value) => value.eta?.let((eta) => dateFormat.format(eta)) ?? '--:--'),
                consumerTooltipListenable: toolheadInfoProvider(machineUUID).selectAs((value) => tr(
                      'pages.dashboard.general.print_card.eta_tooltip',
                      namedArgs: {
                        'avg': value.remaining?.let(secondsToDurationText) ?? '--',
                        'slicer': value.remainingSlicer?.let(secondsToDurationText) ?? '--',
                        'file': value.remainingFile?.let(secondsToDurationText) ?? '--',
                        'filament': value.remainingFilament?.let(secondsToDurationText) ?? '--',
                      },
                    )),
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

          if (asyncValue.isLoading && !asyncValue.isReloading) return const _LoadingCell();

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [child!, Text(asyncValue.requireValue)],
            ),
          );
        },
        child: Text(label),
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
    required this.label,
    required this.consumerListenable,
    required this.consumerTooltipListenable,
  });

  final String label;
  final ProviderListenable<AsyncValue<String>> consumerListenable;
  final ProviderListenable<AsyncValue<String>> consumerTooltipListenable;

  @override
  Widget build(_) => Consumer(
        builder: (context, ref, child) {
          var asyncTooltipValue = ref.watch(consumerTooltipListenable);

          if (asyncTooltipValue.isLoading && !asyncTooltipValue.isReloading) return child!;

          return Tooltip(
            margin: const EdgeInsets.all(8.0),
            textAlign: TextAlign.center,
            message: asyncTooltipValue.requireValue,
            child: child!,
          );
        },
        child: _ConsumerCell(label: label, consumerListenable: consumerListenable),
      );
}
