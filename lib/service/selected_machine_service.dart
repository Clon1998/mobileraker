import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/repository/machine_hive_repository.dart';
import 'package:mobileraker/logger.dart';

final selectedMachineServiceProvider = Provider((ref) {
  return SelectedMachineService(ref);
});

final selectedMachineProvider = StreamProvider<Machine?>(name:'selectedMachineProvider',(ref) {
  ref.listenSelf((previous, next) {logger.wtf('selectedMachineProvider: $next');});

  return ref.watch(selectedMachineServiceProvider).selectedMachine;
});

/// Service handling currently selected machine!
class SelectedMachineService {
  SelectedMachineService(Ref ref)
      : _boxUuid = Hive.box<String>('uuidbox'),
        _machineRepo = ref.watch(machineRepositoryProvider) {
    ref.onDispose(dispose);
    _init();
  }

  final MachineHiveRepository _machineRepo;

  final Box<String> _boxUuid;
  Machine? _selected;
  final StreamController<Machine?> _selectedMachineCtrler =
      StreamController<Machine?>.broadcast();

  Stream<Machine?> get selectedMachine => _selectedMachineCtrler.stream;

  _init() {
    String? selectedUUID = _boxUuid.get('selectedPrinter');
    if (selectedUUID != null) {
      _machineRepo.get(uuid: selectedUUID).then((value) {
        if (value != null) selectMachine(value);
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

      logger.i(
          "Selecting no printer as active Printer. Stream is closed?: ${_selectedMachineCtrler.isClosed}");
      return;
    }

    if (!force && machine == _selected) return;

    await _boxUuid.put('selectedPrinter', machine.key);
    if (!_selectedMachineCtrler.isClosed) {
      _selectedMachineCtrler.add(machine);
      _selected = machine;
    }
  }

  selectNextMachine() async {
    List<Machine> list = await _machineRepo.fetchAll();

    if (list.length < 2) return;
    logger.i('Selecting next machine');
    int indexSelected =
        list.indexWhere((element) => element.uuid == _selected?.uuid);
    int next = (indexSelected + 1) % list.length;
    selectMachine(list[next]);
  }

  selectPreviousMachine() async {
    List<Machine> list = await _machineRepo.fetchAll();
    if (list.length < 2) return;
    logger.i('Selecting previous machine');
    int indexSelected =
        list.indexWhere((element) => element.uuid == _selected?.uuid);
    int prev = (indexSelected - 1 < 0) ? list.length - 1 : indexSelected - 1;
    selectMachine(list[prev]);
  }

  bool isSelectedMachine(Machine toCheck) => toCheck == _selected;

  dispose() {
    _selected = null;
    _selectedMachineCtrler.close();
  }
}
