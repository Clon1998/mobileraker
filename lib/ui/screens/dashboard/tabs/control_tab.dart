/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/setting_service.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/power_api_card.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';
import 'package:mobileraker/ui/screens/dashboard/components/bed_mesh_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/control_extruder_card.dart';

import '../components/fans_card.dart';
import '../components/firmware_retraction_card.dart';
import '../components/grouped_sliders_card.dart';
import '../components/limits_card.dart';
import '../components/macro_group_card.dart';
import '../components/multipliers_card.dart';
import '../components/pins_card.dart';

class ControlTab extends ConsumerWidget {
  const ControlTab(this.machineUUID, {super.key});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var groupSliders = ref.watch(boolSettingProvider(AppSettingKeys.groupSliders, true));

    return PullToRefreshPrinter(
      child: ListView(
        key: const PageStorageKey<String>('cTab'),
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          MacroGroupCard(machineUUID: machineUUID),
          ControlExtruderCard(machineUUID: machineUUID),
          FansCard(machineUUID: machineUUID),
          PinsCard(machineUUID: machineUUID),
          PowerApiCard(machineUUID: machineUUID),
          if (groupSliders) GroupedSlidersCard(machineUUID: machineUUID),
          if (!groupSliders) ...[
            MultipliersCard(machineUUID: machineUUID),
            LimitsCard(machineUUID: machineUUID),
            FirmwareRetractionCard(machineUUID: machineUUID),
          ],
          BedMeshCard(machineUUID: machineUUID),
        ],
      ),
    );
  }
}
