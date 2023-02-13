import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';
import 'package:mobileraker/data/repository/octo_everywhere_repository.dart';


final octoEverywhereHiveRepositoryProvider = Provider((ref) => OctoEverywhereHiveRepository());


class OctoEverywhereHiveRepository extends OctoEverywhereRepository {
  OctoEverywhereHiveRepository() : _boxOcto = Hive.box<OctoEverywhere>('octo');
  final Box<OctoEverywhere> _boxOcto;

  @override
  Future<void> insert(String machineID, OctoEverywhere machine) async {
    await _boxOcto.put(machineID, machine);
  }

  @override
  Future<void> update(OctoEverywhere machine) async {
    // TODO
  }

  @override
  Future<OctoEverywhere?> fetch(String machineID) async {
    return _boxOcto.get(machineID);
  }
}
