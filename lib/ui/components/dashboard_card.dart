/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/misc.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/power_api_card.dart';
import 'package:mobileraker_pro/service/ui/dashboard_layout_service.dart';
import 'package:mobileraker_pro/ui/components/spoolman/spoolman_card.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../screens/dashboard/components/bed_mesh_card.dart';
import '../screens/dashboard/components/control_extruder_card.dart';
import '../screens/dashboard/components/control_xyz_card.dart';
import '../screens/dashboard/components/fans_card.dart';
import '../screens/dashboard/components/firmware_retraction_card.dart';
import '../screens/dashboard/components/grouped_sliders_card.dart';
import '../screens/dashboard/components/limits_card.dart';
import '../screens/dashboard/components/machine_status_card.dart';
import '../screens/dashboard/components/macro_group_card.dart';
import '../screens/dashboard/components/multipliers_card.dart';
import '../screens/dashboard/components/pins_card.dart';
import '../screens/dashboard/components/temperature_card/temperature_sensor_preset_card.dart';
import '../screens/dashboard/components/webcam_card.dart';
import '../screens/dashboard/components/z_offset_card.dart';

part 'dashboard_card.g.dart';

@Riverpod(dependencies: [], keepAlive: true)
DashboardComponentType _cardType(_CardTypeRef ref) {
  throw UnimplementedError();
}

@Riverpod(dependencies: [], keepAlive: true)
String _cardUUID(_CardUUIDRef ref) {
  throw UnimplementedError();
}

@Riverpod(dependencies: [_cardUUID, _cardType])
String dashboardCardUUID(DashboardCardUUIDRef ref, String machineUUID) {
  final dashboard = ref.watch(dashboardLayoutProvider(machineUUID).requireValue());

  if (dashboard.created == null) {
    return ref.watch(_cardTypeProvider).name;
  }

  return ref.watch(_cardUUIDProvider);
}

/// Transforms a [DashboardComponentType] into a widget
class DasboardCard extends StatelessWidget {
  const DasboardCard._({super.key, required this.componentUUID, required this.type, required this.child});

  factory DasboardCard({Key? key, required DashboardComponent component, required String machineUUID}) {
    return DasboardCard._(
        key: key, componentUUID: component.uuid, type: component.type, child: _resolve(component.type, machineUUID));
  }

  factory DasboardCard.preview({Key? key, required DashboardComponentType type}) {
    return DasboardCard._(key: key, componentUUID: 'demo:${type.name}', type: type, child: _resolveDemo(type));
  }

  final DashboardComponentType type;
  final String componentUUID;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // logger.i(
    //     'Building DashboardCard with isDemo: $_isDemo, instance: #${identityHashCode(this)}, child: ${identityHashCode(child)}');

    // This provides the componentUUID to the children without the need to pass it down manually
    // In the future this should not be the UUID but rather the entire component
    return ProviderScope(
      overrides: [
        _cardUUIDProvider.overrideWithValue(componentUUID),
        _cardTypeProvider.overrideWithValue(type),
      ],
      child: child,
    );
  }

  static Widget _resolve(DashboardComponentType type, String machineUUID) {
    return switch (type) {
      DashboardComponentType.machineStatus => MachineStatusCard(machineUUID: machineUUID),
      DashboardComponentType.temperatureSensorPreset => TemperatureSensorPresetCard(machineUUID: machineUUID),
      DashboardComponentType.webcam => WebcamCard(machineUUID: machineUUID),
      DashboardComponentType.controlXYZ => ControlXYZCard(machineUUID: machineUUID),
      DashboardComponentType.zOffset => ZOffsetCard(machineUUID: machineUUID),
      DashboardComponentType.spoolman => SpoolmanCard(machineUUID: machineUUID),
      DashboardComponentType.macroGroup => MacroGroupCard(machineUUID: machineUUID),
      DashboardComponentType.controlExtruder => ControlExtruderCard(machineUUID: machineUUID),
      DashboardComponentType.fans => FansCard(machineUUID: machineUUID),
      DashboardComponentType.pins => PinsCard(machineUUID: machineUUID),
      DashboardComponentType.powerApi => PowerApiCard(machineUUID: machineUUID),
      DashboardComponentType.groupedSliders => GroupedSlidersCard(machineUUID: machineUUID),
      DashboardComponentType.multipliers => MultipliersCard(machineUUID: machineUUID),
      DashboardComponentType.limits => LimitsCard(machineUUID: machineUUID),
      DashboardComponentType.firmwareRetraction => FirmwareRetractionCard(machineUUID: machineUUID),
      DashboardComponentType.bedMesh => BedMeshCard(machineUUID: machineUUID),
      _ => ErrorCard(
          title: const Text('Unknown card type'),
          body: Text('The card type $type is not supported'),
        ),
    };
  }

  static Widget _resolveDemo(DashboardComponentType type) {
    // logger.w('Resolving demo card for $type');
    return switch (type) {
      DashboardComponentType.zOffset => ZOffsetCard.preview(),
      DashboardComponentType.machineStatus => MachineStatusCard.preview(),
      DashboardComponentType.temperatureSensorPreset => TemperatureSensorPresetCard.preview(),
      DashboardComponentType.controlXYZ => ControlXYZCard.preview(),
      DashboardComponentType.spoolman => SpoolmanCard.preview(),
      DashboardComponentType.macroGroup => MacroGroupCard.preview(),
      DashboardComponentType.controlExtruder => ControlExtruderCard.preview(),
      DashboardComponentType.fans => FansCard.preview(),
      DashboardComponentType.pins => PinsCard.preview(),
      DashboardComponentType.powerApi => PowerApiCard.preview(),
      DashboardComponentType.groupedSliders => GroupedSlidersCard.preview(),
      DashboardComponentType.multipliers => MultipliersCard.preview(),
      DashboardComponentType.limits => LimitsCard.preview(),
      DashboardComponentType.firmwareRetraction => FirmwareRetractionCard.preview(),
      DashboardComponentType.bedMesh => BedMeshCard.preview(),
      DashboardComponentType.webcam => WebcamCard.preview(),
      _ => Card(
          child: ListTile(
            title: Text(beautifyName(type.name)),
            subtitle: Text('No preview available yet for ${type.name}'),
          ),
        ),
      // _ => ErrorCard(
      //     title: const Text('Unknown card type'),
      //     body: Text('No preview available for $type'),
      //   ),
    };
  }
}
