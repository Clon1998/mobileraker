/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/ui/components/IconElevatedButton.dart';
import 'package:mobileraker/ui/components/homed_axis_chip.dart';
import 'package:mobileraker/ui/components/range_selector.dart';
import 'package:mobileraker/ui/screens/dashboard/components/async_button_.dart';
import 'package:mobileraker/ui/screens/dashboard/components/control_xyz/control_xyz_card_controller.dart';
import 'package:mobileraker/ui/screens/dashboard/components/toolhead_info/toolhead_info_table.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/general_tab_controller.dart';

class ControlXYZCard extends HookConsumerWidget {
  static const marginForBtns = EdgeInsets.all(10);

  const ControlXYZCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyCanReceiveCommands = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.klippyData.klippyCanReceiveCommands));
    var numberFormat = NumberFormat.decimalPattern(context.locale.languageCode);

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(FlutterIcons.axis_arrow_mco),
            title: const Text('pages.dashboard.general.move_card.title').tr(),
            trailing: const HomedAxisChip(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Column(
                      children: [
                        Row(
                          children: [
                            SquareElevatedIconButton(
                                margin: marginForBtns,
                                onPressed: klippyCanReceiveCommands
                                    ? () => ref
                                        .read(controlXYZCardControllerProvider
                                            .notifier)
                                        .onMoveBtn(PrinterAxis.Y)
                                    : null,
                                child: const Icon(FlutterIcons.upsquare_ant)),
                          ],
                        ),
                        Row(
                          children: [
                            SquareElevatedIconButton(
                                margin: marginForBtns,
                                onPressed: klippyCanReceiveCommands
                                    ? () => ref
                                        .read(controlXYZCardControllerProvider
                                            .notifier)
                                        .onMoveBtn(PrinterAxis.X, false)
                                    : null,
                                child: const Icon(FlutterIcons.leftsquare_ant)),
                            Tooltip(
                              message:
                                  'pages.dashboard.general.move_card.home_xy_tooltip'
                                      .tr(),
                              child: AsyncElevatedButton.squareIcon(
                                margin: marginForBtns,
                                onPressed: klippyCanReceiveCommands
                                    ? () => ref
                                        .read(controlXYZCardControllerProvider
                                            .notifier)
                                        .onHomeAxisBtn(
                                            {PrinterAxis.X, PrinterAxis.Y})
                                    : null,
                                icon: const Icon(Icons.home),
                              ),
                            ),
                            SquareElevatedIconButton(
                                margin: marginForBtns,
                                onPressed: klippyCanReceiveCommands
                                    ? () => ref
                                        .read(controlXYZCardControllerProvider
                                            .notifier)
                                        .onMoveBtn(PrinterAxis.X)
                                    : null,
                                child:
                                    const Icon(FlutterIcons.rightsquare_ant)),
                          ],
                        ),
                        Row(
                          children: [
                            SquareElevatedIconButton(
                              margin: marginForBtns,
                              onPressed: klippyCanReceiveCommands
                                  ? () => ref
                                      .read(controlXYZCardControllerProvider
                                          .notifier)
                                      .onMoveBtn(PrinterAxis.Y, false)
                                  : null,
                              child: const Icon(FlutterIcons.downsquare_ant),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        SquareElevatedIconButton(
                            margin: marginForBtns,
                            onPressed: klippyCanReceiveCommands
                                ? () => ref
                                    .read(controlXYZCardControllerProvider
                                        .notifier)
                                    .onMoveBtn(PrinterAxis.Z)
                                : null,
                            child: const Icon(FlutterIcons.upsquare_ant)),
                        Tooltip(
                          message:
                              'pages.dashboard.general.move_card.home_z_tooltip'
                                  .tr(),
                          child: AsyncElevatedButton.squareIcon(
                              margin: marginForBtns,
                              onPressed: klippyCanReceiveCommands
                                  ? () => ref
                                      .read(controlXYZCardControllerProvider
                                          .notifier)
                                      .onHomeAxisBtn({PrinterAxis.Z})
                                  : null,
                              icon: const Icon(Icons.home)),
                        ),
                        SquareElevatedIconButton(
                            margin: marginForBtns,
                            onPressed: klippyCanReceiveCommands
                                ? () => ref
                                    .read(controlXYZCardControllerProvider
                                        .notifier)
                                    .onMoveBtn(PrinterAxis.Z, false)
                                : null,
                            child: const Icon(FlutterIcons.downsquare_ant)),
                      ],
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: ToolheadInfoTable(
                    rowsToShow: [ToolheadInfoTable.POS_ROW],
                  ),
                ),
                const _ShortCuts(),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      child: Text(
                        '${'pages.dashboard.general.move_card.step_size'.tr()} [mm]',
                      ),
                    ),
                    RangeSelector(
                        selectedIndex: ref.watch(
                            controlXYZCardControllerProvider
                                .select((value) => value.index)),
                        onSelected: ref
                            .read(controlXYZCardControllerProvider.notifier)
                            .onSelectedAxisStepSizeChanged,
                        values: ref.watch(
                            generalTabViewControllerProvider.select((data) {
                          return data.valueOrNull!.settings.moveSteps;
                        })).map((e) {
                          return numberFormat.format(e);
                        }).toList())
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortCuts extends ConsumerWidget {
  const _ShortCuts({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyCanReceiveCommands = ref.watch(generalTabViewControllerProvider
        .select((data) => data.value!.klippyData.klippyCanReceiveCommands));

    var directActions = ref.watch(controlXYZCardControllerProvider
        .select((value) => value.directActions));
    var moreActions = ref.watch(
        controlXYZCardControllerProvider.select((value) => value.moreActions));

    return Wrap(
      runSpacing: 4,
      spacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ...directActions
            .map(
              (e) => Tooltip(
                message: e.description,
                child: AsyncElevatedButton.icon(
                  onPressed: klippyCanReceiveCommands ? e.callback : null,
                  icon: Icon(e.icon),
                  label: Text(e.title.toUpperCase()),
                ),
              ),
            )
            .toList(),
        _MoreActionsPopup(
          klippyCanReceiveCommands: klippyCanReceiveCommands,
          entries: moreActions,
        ),
      ],
    );
  }
}

class _MoreActionsPopup extends ConsumerWidget {
  const _MoreActionsPopup({
    Key? key,
    required this.entries,
    required this.klippyCanReceiveCommands,
  }) : super(key: key);
  final List<QuickAction> entries;
  final bool klippyCanReceiveCommands;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    bool enabled =
        klippyCanReceiveCommands && entries.any((e) => e.callback != null);

    return PopupMenuButton(
        enabled: enabled,
        position: PopupMenuPosition.over,
        itemBuilder: (BuildContext context) => entries
            .map(
              (e) => PopupMenuItem(
                enabled: klippyCanReceiveCommands,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onTap: e.callback,
                child: ListTile(
                  enabled: e.callback != null,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(e.icon),
                  title: Text(e.title),
                  subtitle: Text(e.description),
                ),
              ),
            )
            .toList(),
        child: ElevatedButton.icon(
            style: enabled
                ? ElevatedButton.styleFrom(
                    disabledBackgroundColor: themeData.colorScheme.primary,
                    disabledForegroundColor: themeData.colorScheme.onPrimary)
                : null,
            onPressed: null,
            icon: const Icon(Icons.more_vert),
            label:
                const Text('@.upper:pages.dashboard.general.move_card.more_btn')
                    .tr()));
  }
}
