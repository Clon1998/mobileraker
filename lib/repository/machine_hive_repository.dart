import 'package:hive/hive.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/repository/machine_repository.dart';

class MachineHiveRepository implements MachineRepository {
  late final _boxmachines = Hive.box<Machine>('printers');


  Future<void> insert(Machine machine) async {
    await _boxmachines.put(machine.uuid, machine);
    return;
  }


  Future<void> update(Machine machine) async {
    await machine.save();

    return;
  }

  Future<Machine?> get({String? uuid, int index=-1}) async {
    assert(uuid != null || index >= 0, 'Either provide an uuid or an index >= 0');
    if (uuid != null)
      return _boxmachines.get(uuid);
    else
      return _boxmachines.getAt(index);
  }

  Future<Machine> remove(String uuid) async {
    Machine? machine = await get(uuid: uuid);

    machine?.delete();
    return machine!;
  }

  Future<List<Machine>> fetchAll() {
    return Future.value(_boxmachines.values.toList(growable: false));
  }

  Future<int> count() {
    return Future.value(_boxmachines.length);
  }
}
