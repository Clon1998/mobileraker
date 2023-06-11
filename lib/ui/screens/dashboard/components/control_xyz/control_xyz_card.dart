/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
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
    var iconThemeData = IconTheme.of(context);

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
                            Container(
                              margin: marginForBtns,
                              height: 40,
                              width: 40,
                              child: ElevatedButton(
                                  onPressed: klippyCanReceiveCommands
                                      ? () => ref
                                          .read(controlXYZCardControllerProvider
                                              .notifier)
                                          .onMoveBtn(PrinterAxis.Y)
                                      : null,
                                  child: const Icon(FlutterIcons.upsquare_ant)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              margin: marginForBtns,
                              height: 40,
                              width: 40,
                              child: ElevatedButton(
                                  onPressed: klippyCanReceiveCommands
                                      ? () => ref
                                          .read(controlXYZCardControllerProvider
                                              .notifier)
                                          .onMoveBtn(PrinterAxis.X, false)
                                      : null,
                                  child:
                                      const Icon(FlutterIcons.leftsquare_ant)),
                            ),
                            Container(
                              margin: marginForBtns,
                              height: 40,
                              width: 40,
                              child: Tooltip(
                                message:
                                    'pages.dashboard.general.move_card.home_xy_tooltip'
                                        .tr(),
                                child: AsyncButton(
                                    onPressed: klippyCanReceiveCommands &&
                                            ref.watch(
                                                controlXYZCardControllerProvider
                                                    .select((value) =>
                                                        !value.homing))
                                        ? () => ref
                                            .read(
                                                controlXYZCardControllerProvider
                                                    .notifier)
                                            .onHomeAxisBtn(
                                                {PrinterAxis.X, PrinterAxis.Y})
                                        : null,
                                    child: const Icon(Icons.home)),
                              ),
                            ),
                            Container(
                              margin: marginForBtns,
                              height: 40,
                              width: 40,
                              child: ElevatedButton(
                                  onPressed: klippyCanReceiveCommands
                                      ? () => ref
                                          .read(controlXYZCardControllerProvider
                                              .notifier)
                                          .onMoveBtn(PrinterAxis.X)
                                      : null,
                                  child:
                                      const Icon(FlutterIcons.rightsquare_ant)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              margin: marginForBtns,
                              height: 40,
                              width: 40,
                              child: ElevatedButton(
                                onPressed: klippyCanReceiveCommands
                                    ? () => ref
                                        .read(controlXYZCardControllerProvider
                                            .notifier)
                                        .onMoveBtn(PrinterAxis.Y, false)
                                    : null,
                                child: const Icon(FlutterIcons.downsquare_ant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Container(
                          margin: marginForBtns,
                          height: 40,
                          width: 40,
                          child: ElevatedButton(
                              onPressed: klippyCanReceiveCommands
                                  ? () => ref
                                      .read(controlXYZCardControllerProvider
                                          .notifier)
                                      .onMoveBtn(PrinterAxis.Z)
                                  : null,
                              child: const Icon(FlutterIcons.upsquare_ant)),
                        ),
                        Container(
                          margin: marginForBtns,
                          height: 40,
                          width: 40,
                          child: Tooltip(
                            message:
                                'pages.dashboard.general.move_card.home_z_tooltip'
                                    .tr(),
                            child: AsyncButton(
                                onPressed: klippyCanReceiveCommands &&
                                        ref.watch(
                                            controlXYZCardControllerProvider
                                                .select(
                                                    (value) => !value.homing))
                                    ? () => ref
                                        .read(controlXYZCardControllerProvider
                                            .notifier)
                                        .onHomeAxisBtn({PrinterAxis.Z})
                                    : null,
                                child: const Icon(Icons.home)),
                          ),
                        ),
                        Container(
                          margin: marginForBtns,
                          height: 40,
                          width: 40,
                          child: ElevatedButton(
                              onPressed: klippyCanReceiveCommands
                                  ? () => ref
                                      .read(controlXYZCardControllerProvider
                                          .notifier)
                                      .onMoveBtn(PrinterAxis.Z, false)
                                  : null,
                              child: const Icon(FlutterIcons.downsquare_ant)),
                        ),
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
                Wrap(
                  runSpacing: 4,
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Tooltip(
                      message:
                          'pages.dashboard.general.move_card.home_all_tooltip'
                              .tr(),
                      child: AsyncButton.icon(
                        onPressed: klippyCanReceiveCommands &&
                                ref.watch(controlXYZCardControllerProvider
                                    .select((value) => !value.homing))
                            ? () =>
                                ref
                                    .read(controlXYZCardControllerProvider
                                        .notifier)
                                    .onHomeAxisBtn({
                                  PrinterAxis.X,
                                  PrinterAxis.Y,
                                  PrinterAxis.Z
                                })
                            : null,
                        icon: const Icon(Icons.home),
                        label: Text(
                            'pages.dashboard.general.move_card.home_all_btn'
                                .tr()
                                .toUpperCase()),
                      ),
                    ),
                    if (ref.watch(generalTabViewControllerProvider.select(
                        (data) =>
                            data.valueOrNull?.printerData.configFile
                                .hasQuadGantry ==
                            true)))
                      Tooltip(
                        message: 'pages.dashboard.general.move_card.qgl_tooltip'
                            .tr(),
                        child: AsyncButton.icon(
                          onPressed: klippyCanReceiveCommands &&
                                  ref.watch(controlXYZCardControllerProvider
                                      .select((value) => !value.qgl))
                              ? ref
                                  .read(
                                      controlXYZCardControllerProvider.notifier)
                                  .onQuadGantry
                              : null,
                          icon: const Icon(FlutterIcons.quadcopter_mco),
                          label: Text(
                              'pages.dashboard.general.move_card.qgl_btn'
                                  .tr()
                                  .toUpperCase()),
                        ),
                      ),
                    if (ref.watch(generalTabViewControllerProvider.select(
                        (data) =>
                            data.valueOrNull?.printerData.configFile
                                .hasBedMesh ==
                            true)))
                      Tooltip(
                        message:
                            'pages.dashboard.general.move_card.mesh_tooltip'
                                .tr(),
                        child: AsyncButton.icon(
                          onPressed: klippyCanReceiveCommands &&
                                  ref.watch(controlXYZCardControllerProvider
                                      .select((value) => !value.mesh))
                              ? ref
                                  .read(
                                      controlXYZCardControllerProvider.notifier)
                                  .onBedMesh
                              : null,
                          icon: const Icon(FlutterIcons.map_marker_path_mco),
                          label: Text(
                              'pages.dashboard.general.move_card.mesh_btn'
                                  .tr()
                                  .toUpperCase()),
                          // color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    if (ref.watch(generalTabViewControllerProvider.select(
                        (data) =>
                            data.valueOrNull?.printerData.configFile
                                .hasScrewTiltAdjust ==
                            true)))
                      Tooltip(
                        message: 'pages.dashboard.general.move_card.stc_tooltip'
                            .tr(),
                        child: ElevatedButton.icon(
                          onPressed: klippyCanReceiveCommands &&
                                  ref.watch(controlXYZCardControllerProvider
                                      .select((value) => !value.screwTilt))
                              ? ref
                                  .read(
                                      controlXYZCardControllerProvider.notifier)
                                  .onScrewTiltCalc
                              : null,
                          icon: const Icon(
                              FlutterIcons.screw_machine_flat_top_mco),
                          label: Text(
                              'pages.dashboard.general.move_card.stc_btn'
                                  .tr()
                                  .toUpperCase()),
                        ),
                      ),
                    if (ref.watch(generalTabViewControllerProvider.select(
                        (data) =>
                            data.valueOrNull?.printerData.configFile.hasZTilt ==
                            true)))
                      Tooltip(
                        message:
                            'pages.dashboard.general.move_card.ztilt_tooltip'
                                .tr(),
                        child: AsyncButton.icon(
                          onPressed: klippyCanReceiveCommands &&
                                  ref.watch(controlXYZCardControllerProvider
                                      .select((value) => !value.zTilt))
                              ? ref
                                  .read(
                                      controlXYZCardControllerProvider.notifier)
                                  .onZTiltAdjust
                              : null,
                          icon:
                              const Icon(FlutterIcons.unfold_less_vertical_mco),
                          label: Text(
                              'pages.dashboard.general.move_card.ztilt_btn'
                                  .tr()
                                  .toUpperCase()),
                        ),
                      ),
                    Tooltip(
                      message:
                          'pages.dashboard.general.move_card.m84_tooltip'.tr(),
                      child: AsyncButton.icon(
                        onPressed: klippyCanReceiveCommands &&
                                ref.watch(controlXYZCardControllerProvider
                                    .select((value) => !value.motorsOff))
                            ? ref
                                .read(controlXYZCardControllerProvider.notifier)
                                .onMotorOff
                            : null,
                        icon: const Icon(Icons.near_me_disabled),
                        label: const Text(
                                'pages.dashboard.general.move_card.m84_btn')
                            .tr(),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      child: Text(
                          '${'pages.dashboard.general.move_card.step_size'.tr()} [mm]',),
                    ),
                    RangeSelector(
                        selectedIndex: ref.watch(
                            controlXYZCardControllerProvider
                                .select((value) => value.index)),
                        onSelected: ref
                            .read(controlXYZCardControllerProvider.notifier)
                            .onSelectedAxisStepSizeChanged,
                        values: ref
                            .watch(
                                generalTabViewControllerProvider.select((data) {
                              return data.valueOrNull!.settings.moveSteps;
                            }))
                            .map((e) => e.toString())
                            .toList())
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
