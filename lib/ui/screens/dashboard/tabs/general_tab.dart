/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/machine_deletion_warning.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';
import 'package:mobileraker/ui/components/supporter_ad.dart';
import 'package:mobileraker/ui/screens/dashboard/components/control_xyz_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/machine_status_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/webcam_card.dart';
import 'package:mobileraker_pro/ui/components/spoolman/spoolman_card.dart';

import '../../../components/remote_announcements.dart';
import '../../../components/remote_connection_active_card.dart';
import '../components/temperature_card/temperature_sensor_preset_card.dart';
import '../components/z_offset_card.dart';

class GeneralTab extends ConsumerWidget {
  const GeneralTab(this.machineUUID, {super.key});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PullToRefreshPrinter(
      child: ListView(
        // physics: const BouncingScrollPhysics(), // Reproduces the iOS bounce effect and cam jumping scroll
        key: const PageStorageKey('gTab'),
        padding: const EdgeInsets.only(bottom: 20),
        shrinkWrap: true,
        children: [
          const RemoteAnnouncements(),
          const MachineDeletionWarning(),
          const SupporterAd(),
          RemoteConnectionActiveCard(machineId: machineUUID),
          MachineStatusCard(machineUUID: machineUUID),
          TemperatureSensorPresetCard(machineUUID: machineUUID),
          WebcamCard(machineUUID: machineUUID),
          ControlXYZCard(machineUUID: machineUUID),
          ZOffsetCard(machineUUID: machineUUID),
          SpoolmanCard(machineUUID: machineUUID),
        ],
      ),
    );
  }
}
