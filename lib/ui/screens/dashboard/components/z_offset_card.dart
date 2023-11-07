/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../components/IconElevatedButton.dart';
import '../../../components/range_selector.dart';
import '../tabs/general_tab_controller.dart';

class ZOffsetCard extends ConsumerWidget {
  const ZOffsetCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var zOffset = ref.watch(printerSelectedProvider.select((data) => data.value!.zOffset));
    var klippyCanReceiveCommands = ref
        .watch(generalTabViewControllerProvider.selectAs((value) => value.klippyData.klippyCanReceiveCommands))
        .valueOrNull!;

    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
              leading: const Icon(FlutterIcons.align_vertical_middle_ent),
              title: const Text('pages.dashboard.general.baby_step_card.title').tr(),
              trailing: Chip(
                avatar: Icon(
                  FlutterIcons.progress_wrench_mco,
                  color: Theme.of(context).iconTheme.color,
                  size: 20,
                ),
                label: Text('${zOffset.toStringAsFixed(3)}mm'),
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Column(
                  children: [
                    SquareElevatedIconButton(
                        margin: const EdgeInsets.all(10),
                        onPressed: klippyCanReceiveCommands
                            ? () => ref.read(babyStepControllerProvider.notifier).onBabyStepping()
                            : null,
                        child: const Icon(FlutterIcons.upsquare_ant)),
                    SquareElevatedIconButton(
                        margin: const EdgeInsets.all(10),
                        onPressed: klippyCanReceiveCommands
                            ? () => ref.read(babyStepControllerProvider.notifier).onBabyStepping(false)
                            : null,
                        child: const Icon(FlutterIcons.downsquare_ant)),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${'pages.dashboard.general.move_card.step_size'.tr()} [mm]'),
                    ),
                    RangeSelector(
                        selectedIndex: ref.watch(babyStepControllerProvider),
                        onSelected: ref.read(babyStepControllerProvider.notifier).onSelectedBabySteppingSizeChanged,
                        values: ref
                            .read(generalTabViewControllerProvider.select((data) => data.value!.settings.babySteps))
                            .map((e) => e.toString())
                            .toList()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
