/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/util/logger.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repository/machine_hive_repository.dart';

part 'selected_machine_service.g.dart';

@riverpod
SelectedMachineService selectedMachineService(SelectedMachineServiceRef ref) {
  return SelectedMachineService(ref);
}

@riverpod
Stream<Machine?> selectedMachine(SelectedMachineRef ref) {
  ref.keepAlive();
  return ref.watch(selectedMachineServiceProvider).selectedMachine;
}

/// Service handling currently selected machine!
class SelectedMachineService {
  SelectedMachineService(this.ref)
      : _boxUuid = Hive.box<String>('uuidbox'),
        _machineRepo = ref.watch(machineRepositoryProvider) {
    ref.onDispose(dispose);
    _init();
  }

  final AutoDisposeRef ref;

  final MachineHiveRepository _machineRepo;

  final Box<String> _boxUuid;
  Machine? _selected;
  final StreamController<Machine?> _selectedMachineCtrler = StreamController<Machine?>();

  Stream<Machine?> get selectedMachine => _selectedMachineCtrler.stream;

  ThemeService get _themeService => ref.read(themeServiceProvider);

  _init() {
    String? selectedUUID = _boxUuid.get('selectedPrinter');
    if (selectedUUID == null) {
      selectMachine(null);
    } else {
      _machineRepo.get(uuid: selectedUUID).then((value) {
        selectMachine(value);
      });
    }
  }

  selectMachine(Machine? machine, [bool force = false]) async {
    logger.i('Selecting machine ${machine?.name}');
    if (machine == null) {
      // This case sets no printer as active!
      await _boxUuid.delete('selectedPrinter');
      if (!_selectedMachineCtrler.isClosed) {
        _selectedMachineCtrler.add(null);
        _selected = null;
      }
      _themeService.selectSystemThemePack();
      logger.i("Selecting no printer as active Printer. Stream is closed?: ${_selectedMachineCtrler.isClosed}");
      return;
    }

    if (!force && machine == _selected) return;

    await _boxUuid.put('selectedPrinter', machine.key);
    if (!_selectedMachineCtrler.isClosed) {
      _selectedMachineCtrler.add(machine);
      _selected = machine;

      if (ref.read(isSupporterProvider) && machine.printerThemePack != -1) {
        _themeService.selectThemeIndex(machine.printerThemePack);
      } else {
        _themeService.selectSystemThemePack();
      }
    }
  }

  selectNextMachine() async {
    List<Machine> list = await _machineRepo.fetchAll();

    if (list.length < 2) return;
    logger.i('Selecting next machine');
    int indexSelected = list.indexWhere((element) => element.uuid == _selected?.uuid);
    int next = (indexSelected + 1) % list.length;
    selectMachine(list[next]);
  }

  selectPreviousMachine() async {
    List<Machine> list = await _machineRepo.fetchAll();
    if (list.length < 2) return;
    logger.i('Selecting previous machine');
    int indexSelected = list.indexWhere((element) => element.uuid == _selected?.uuid);
    int prev = (indexSelected - 1 < 0) ? list.length - 1 : indexSelected - 1;
    selectMachine(list[prev]);
  }

  bool isSelectedMachine(Machine toCheck) => toCheck.uuid == _boxUuid.get('selectedPrinter');

  dispose() {
    _selected = null;
    _selectedMachineCtrler.close();
  }
}
