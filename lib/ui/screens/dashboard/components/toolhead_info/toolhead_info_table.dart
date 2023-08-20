/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/time_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/date_format_service.dart';
import 'package:mobileraker/ui/screens/dashboard/components/toolhead_info/toolhead_info_table_controller.dart';

class ToolheadInfoTable extends ConsumerWidget {
  static const String POS_ROW = "p";
  static const String MOV_ROW = "m";

  final List<String> rowsToShow;

  const ToolheadInfoTable({Key? key, this.rowsToShow = const [POS_ROW, MOV_ROW]}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var toolheadInfo = ref.watch(toolheadInfoProvider);

    return AnimatedSwitcher(
        switchInCurve: Curves.easeInOutBack,
        duration: kThemeAnimationDuration,
        transitionBuilder: (child, anim) => SizeTransition(
            sizeFactor: anim,
            child: FadeTransition(
              opacity: anim,
              child: child,
            )),
        child: toolheadInfo.hasValue
            ? _ToolheadData(toolheadInfo: toolheadInfo.value!, rowsToShow: rowsToShow)
            : const LinearProgressIndicator());
  }
}

class _ToolheadData extends ConsumerWidget {
  const _ToolheadData({
    Key? key,
    required this.toolheadInfo,
    required this.rowsToShow,
  }) : super(key: key);

  final ToolheadInfo toolheadInfo;
  final List<String> rowsToShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var labelStyle = Theme.of(context).textTheme.bodySmall;

    var position = ref.watch(settingServiceProvider).readBool(AppSettingKeys.applyOffsetsToPostion)
        ? toolheadInfo.postion
        : toolheadInfo.livePosition;
    return Table(
      border: TableBorder(
          horizontalInside: BorderSide(
              width: 1, color: Theme.of(context).dividerColor, style: BorderStyle.solid)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FractionColumnWidth(.1),
      },
      children: [
        if (rowsToShow.contains(ToolheadInfoTable.POS_ROW))
          TableRow(children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(FlutterIcons.axis_arrow_mco),
            ),
            _TableCell(label: 'X', value: position[0].toStringAsFixed(2)),
            _TableCell(label: 'Y', value: position[1].toStringAsFixed(2)),
            _TableCell(label: 'Z', value: position[2].toStringAsFixed(2)),
          ]),
        if (rowsToShow.contains(ToolheadInfoTable.MOV_ROW) && toolheadInfo.printingOrPaused) ...[
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(FlutterIcons.layers_fea),
              ),
              _TableCell(
                  label: tr('pages.dashboard.general.print_card.speed'),
                  value: '${toolheadInfo.mmSpeed} mm/s'),
              _TableCell(
                  label: tr('pages.dashboard.general.print_card.layer'),
                  value: '${toolheadInfo.currentLayer}/${toolheadInfo.maxLayers}'),
              _TableCell(
                  label: tr('pages.dashboard.general.print_card.elapsed'),
                  value: secondsToDurationText(toolheadInfo.totalDuration)),
            ],
          ),
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(FlutterIcons.printer_3d_mco),
              ),
              _TableCell(
                  label: tr('pages.dashboard.general.print_card.flow'),
                  value: '${toolheadInfo.currentFlow ?? 0} mm³/s'),
              Tooltip(
                textAlign: TextAlign.center,
                message: tr('pages.dashboard.general.print_card.filament_tooltip', args: [
                  toolheadInfo.usedFilamentPerc.toStringAsFixed(0),
                  toolheadInfo.usedFilament?.toStringAsFixed(1) ?? '0',
                  toolheadInfo.totalFilament?.toStringAsFixed(1) ?? '-'
                ]),
                child: _TableCell(
                    label: tr('pages.dashboard.general.print_card.filament'),
                    value: '${toolheadInfo.usedFilament?.toStringAsFixed(1) ?? 0} m'),
              ),
              Tooltip(
                  textAlign: TextAlign.end,
                  message: tr('pages.dashboard.general.print_card.eta_tooltip', namedArgs: {
                    'avg': toolheadInfo.remaining?.let(secondsToDurationText) ?? '--',
                    'slicer': toolheadInfo.remainingSlicer?.let(secondsToDurationText) ?? '--',
                    'file': toolheadInfo.remainingFile?.let(secondsToDurationText) ?? '--',
                    'filament': toolheadInfo.remainingFilament?.let(secondsToDurationText) ?? '--',
                  }),
                  child: _TableCell(
                      label: tr('pages.dashboard.general.print_card.eta'),
                      value: toolheadInfo.eta?.let(
                              (eta) => ref.read(dateFormatServiceProvider).Hm().format(eta)) ??
                          '--:--')),
            ],
          ),
        ]
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label),
            Text(value),
          ],
        ));
  }
}
