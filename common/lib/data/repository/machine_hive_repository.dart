/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'machine_repository.dart';

part 'machine_hive_repository.g.dart';

@Riverpod(keepAlive: true)
MachineHiveRepository machineRepository(MachineRepositoryRef ref) => MachineHiveRepository();

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
    assert(uuid != null || index >= 0, 'Either provide an uuid or an index >= 0');
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
  Future<List<Machine>> fetchAll() async {
    return _boxMachines.values.toList(growable: false);
  }

  @override
  Future<int> count() async {
    return _boxMachines.length;
  }
}
