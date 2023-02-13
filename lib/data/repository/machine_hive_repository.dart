import 'package:hive/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/model/hive/machine.dart';

import 'machine_repository.dart';

final machineRepositoryProvider = Provider((ref) => MachineHiveRepository(),name:'machineRepositoryProvider');

class MachineHiveRepository implements MachineRepository {
  MachineHiveRepository() : _boxMachines = Hive.box<Machine>('printers');
  final Box<Machine> _boxMachines;

  @override
  Future<void> insert(Machine machine) async {
    machine.lastModified = DateTime.now();
    await _boxMachines.put(machine.uuid, machine);
    return;
  }

  @override
  Future<void> update(Machine machine) async {
    await machine.save();

    return;
  }

  @override
  Future<Machine?> get({String? uuid, int index = -1}) async {
    assert(
        uuid != null || index >= 0, 'Either provide an uuid or an index >= 0');
    if (uuid != null) {
      return _boxMachines.get(uuid);
    } else {
      return _boxMachines.getAt(index);
    }
  }

  @override
  Future<Machine> remove(String uuid) async {
    Machine? machine = await get(uuid: uuid);

    machine?.delete();
    return machine!;
  }

  @override
  Future<List<Machine>> fetchAll() {
    return Future.value(_boxMachines.values.toList(growable: false));
  }

  @override
  Future<int> count() {
    return Future.value(_boxMachines.length);
  }
}
