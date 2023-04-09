import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/screens/dashboard/components/toolhead_info/toolhead_info_table_controller.dart';
import 'package:mobileraker/util/time_util.dart';

class ToolheadInfoTable extends ConsumerWidget {
  static const String POS_ROW = "p";
  static const String MOV_ROW = "m";

  final List<String> rowsToShow;

  const ToolheadInfoTable(
      {Key? key, this.rowsToShow = const [POS_ROW, MOV_ROW]})
      : super(key: key);

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
            ? _ToolheadData(
                toolheadInfo: toolheadInfo.value!, rowsToShow: rowsToShow)
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
    var position = ref.watch(settingServiceProvider).readBool(useOffsetPosKey)
        ? toolheadInfo.postion
        : toolheadInfo.livePosition;
    return Table(
      border: TableBorder(
          horizontalInside: BorderSide(
              width: 1,
              color: Theme.of(context).dividerColor,
              style: BorderStyle.solid)),
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
            Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('X'),
                    Text(position[0].toStringAsFixed(2)),
                  ],
                )),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Y'),
                  Text(position[1].toStringAsFixed(2)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('Z'),
                  Text(position[2].toStringAsFixed(2)),
                ],
              ),
            ),
          ]),
        if (rowsToShow.contains(ToolheadInfoTable.MOV_ROW) &&
            toolheadInfo.printingOrPaused) ...[
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(FlutterIcons.layers_fea),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('pages.dashboard.general.print_card.speed').tr(),
                    Text('${toolheadInfo.mmSpeed} mm/s'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('pages.dashboard.general.print_card.layer').tr(),
                    Text(
                        '${toolheadInfo.currentLayer}/${toolheadInfo.maxLayers}'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('pages.dashboard.general.print_card.elapsed')
                        .tr(),
                    Text(secondsToDurationText(toolheadInfo.totalDuration)),
                  ],
                ),
              ),
            ],
          ),
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(FlutterIcons.printer_3d_mco),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('pages.dashboard.general.print_card.flow').tr(),
                    Text('${toolheadInfo.currentFlow ?? 0} mm³/s'),
                  ],
                ),
              ),
              Tooltip(
                textAlign: TextAlign.center,
                message: tr('pages.dashboard.general.print_card.filament_used',
                    args: [
                      toolheadInfo.usedFilamentPerc.toStringAsFixed(0),
                      toolheadInfo.usedFilament?.toStringAsFixed(1) ?? '0',
                      toolheadInfo.totalFilament?.toStringAsFixed(1) ?? '-'
                    ]),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('pages.dashboard.general.print_card.filament')
                          .tr(),
                      Text(
                          '${toolheadInfo.usedFilament?.toStringAsFixed(1) ?? 0} m'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('pages.dashboard.general.print_card.eta').tr(),
                    Text((toolheadInfo.eta != null)
                        ? DateFormat.Hm().format(toolheadInfo.eta!)
                        : '--:--'),
                  ],
                ),
              ),
            ],
          ),
        ]
      ],
    );
  }
}
