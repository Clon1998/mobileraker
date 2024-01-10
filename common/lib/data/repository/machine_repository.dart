/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';

abstract class MachineRepository {
  Future<void> insert(Machine machine);

  Future<void> update(Machine machine);

  Future<Machine?> get({String? uuid, int index = -1});

  Future<Machine> remove(String uuid);

  Future<List<Machine>> fetchAll();

  Future<int> count();
}
