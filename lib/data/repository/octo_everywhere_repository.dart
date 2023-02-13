
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';

abstract class OctoEverywhereRepository {
  Future<void> insert(String machineID, OctoEverywhere machine);

  Future<void> update(OctoEverywhere machine);


  Future<OctoEverywhere?> fetch(String machineID);
}