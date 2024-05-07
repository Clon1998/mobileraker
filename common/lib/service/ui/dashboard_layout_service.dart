/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:common/data/repository/dashboard_layout_hive_repository.dart';
import 'package:common/data/repository/dashboard_layout_repository.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/util/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/model/hive/dashboard_component.dart';
import '../../data/model/hive/dashboard_layout.dart';
import '../../data/model/hive/dashboard_tab.dart';
import '../../data/model/hive/machine.dart';

part 'dashboard_layout_service.g.dart';

@riverpod
Future<DashboardLayout> dashboardLayout(DashboardLayoutRef ref, String machineUUID) async {
  var layoutService = ref.watch(dashboardLayoutServiceProvider);
  var machine = await ref.watch(machineProvider(machineUUID).future);
  if (machine == null) {
    throw ArgumentError('Machine with uuid $machineUUID not found');
  }

  logger.i('Fetching dashboard layout for machine ${machine.name} (${machine.uuid})');

  return layoutService.fetchDashboardLayoutForMachine(machine);
}

@riverpod
DashboardLayoutService dashboardLayoutService(DashboardLayoutServiceRef ref) {
  ref.keepAlive();
  return DashboardLayoutService(ref);
}

class DashboardLayoutService {
  DashboardLayoutService(DashboardLayoutServiceRef ref)
      : _ref = ref,
        _repository = ref.watch(dashboardLayoutHiveRepositoryProvider),
        _machineService = ref.watch(machineServiceProvider) {
    ref.onDispose(dispose);
  }

  final DashboardLayoutServiceRef _ref;

  final DashboardLayoutRepository _repository;

  final MachineService _machineService;

  /// Returns the default dashboard layout. Defined by me
  DashboardLayout defaultDashboardLayout() {
    return DashboardLayout(name: 'Default', tabs: [
      DashboardTab(name: 'General', icon: 'icon', components: [
        DashboardComponent(type: DashboardComponentType.machineStatus),
        DashboardComponent(type: DashboardComponentType.temperatureSensorPreset),
        DashboardComponent(type: DashboardComponentType.webcam),
        DashboardComponent(type: DashboardComponentType.controlXYZ),
        DashboardComponent(type: DashboardComponentType.zOffset),
        DashboardComponent(type: DashboardComponentType.spoolman),
      ]),
      DashboardTab(name: 'Control', icon: 'icon', components: [
        DashboardComponent(type: DashboardComponentType.macroGroup),
        DashboardComponent(type: DashboardComponentType.controlExtruder),
        DashboardComponent(type: DashboardComponentType.fans),
        DashboardComponent(type: DashboardComponentType.pins),
        DashboardComponent(type: DashboardComponentType.powerApi),
        DashboardComponent(type: DashboardComponentType.multipliers),
        DashboardComponent(type: DashboardComponentType.bedMesh),
      ]),
    ]);
  }

  Future<DashboardLayout> fetchDashboardLayoutForMachine(Machine machine) async {
    if (machine.dashboardLayout == null) {
      logger.e('Machine with uuid ${machine.name} (${machine.uuid}) has no dashboard layout');
      return defaultDashboardLayout();
    }

    DashboardLayout? layout = await _repository.read(uuid: machine.dashboardLayout!);

    if (layout == null) {
      logger.e('DashboardLayout with uuid ${machine.dashboardLayout} not found');
      return defaultDashboardLayout();
    }

    logger.i('Fetched dashboard layout for machine ${machine.name} (${machine.uuid})');
    return layout;
  }

  Future<void> saveDashboardLayoutForMachine(String machineUUID, DashboardLayout layout) async {
    // This is only a MVP/Prototype...
    var machineService = _ref.read(machineServiceProvider);
    var machine = await machineService.fetch(machineUUID);
    if (machine == null) {
      logger.e('Machine with uuid $machineUUID not found');
      return;
    }
    logger.i('Saving dashboard layout for machine ${machine.name} (${machine.uuid})');
    machine.dashboardLayout = layout.uuid;

    if (layout.created == null) {
      await _repository.create(layout);
    } else {
      await _repository.update(layout);
    }
    await _machineService.updateMachine(machine);
  }

  void dispose() {
    logger.i('DashboardLayoutService disposed');
  }
}
