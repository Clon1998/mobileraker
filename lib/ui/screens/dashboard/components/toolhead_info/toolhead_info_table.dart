import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
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
    return AsyncValueWidget(
      skipLoadingOnReload: true,
      // dont ask me why but this.selectAs prevents rebuild on the exact same value...
      value: ref.watch(toolheadInfoProvider),
      data: (ToolheadInfo moveTableState) {
        var position =
            ref.watch(settingServiceProvider).readBool(useOffsetPosKey)
                ? moveTableState.postion
                : moveTableState.livePosition;
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
            if (rowsToShow.contains(POS_ROW))
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
            if (rowsToShow.contains(MOV_ROW) &&
                moveTableState.printingOrPaused) ...[
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
                        const Text('pages.dashboard.general.print_card.speed')
                            .tr(),
                        Text('${moveTableState.mmSpeed} mm/s'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('pages.dashboard.general.print_card.layer')
                            .tr(),
                        Text(
                            '${moveTableState.currentLayer}/${moveTableState.maxLayers}'),
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
                        Text(secondsToDurationText(
                            moveTableState.totalDuration)),
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
                        const Text('pages.dashboard.general.print_card.flow')
                            .tr(),
                        Text('${moveTableState.currentFlow ?? 0} mm³/s'),
                      ],
                    ),
                  ),
                  Tooltip(
                    textAlign: TextAlign.center,
                    message: tr(
                        'pages.dashboard.general.print_card.filament_used',
                        args: [
                          moveTableState.usedFilamentPerc.toStringAsFixed(0),
                          moveTableState.usedFilament?.toStringAsFixed(1) ??
                              '0',
                          moveTableState.totalFilament?.toStringAsFixed(1) ??
                              '-'
                        ]),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                                  'pages.dashboard.general.print_card.filament')
                              .tr(),
                          Text(
                              '${moveTableState.usedFilament?.toStringAsFixed(1) ?? 0} m'),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('pages.dashboard.general.print_card.eta')
                            .tr(),
                        Text((moveTableState.eta != null)
                            ? DateFormat.Hm().format(moveTableState.eta!)
                            : '--:--'),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          ],
        );
      },
    );
  }
}
