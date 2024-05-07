/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../util/logger.dart';
import 'dashboard_layout_repository.dart';

part 'dashboard_layout_hive_repository.g.dart';

@Riverpod(keepAlive: true)
DashboardLayoutHiveRepository dashboardLayoutHiveRepository(DashboardLayoutHiveRepositoryRef ref) {
  return DashboardLayoutHiveRepository();
}

class DashboardLayoutHiveRepository implements DashboardLayoutRepository {
  DashboardLayoutHiveRepository() : _box = Hive.box<DashboardLayout>('dashboard_layouts');

  final Box<DashboardLayout> _box;

  @override
  Future<List<DashboardLayout>> all() async {
    logger.i('[DashboardLayoutHiveRepository] Fetching all dashboard layouts');
    return _box.values.toList(growable: false);
  }

  @override
  Future<int> count() async {
    logger.i('[DashboardLayoutHiveRepository] Counting all dashboard layouts');
    return _box.length;
  }

  @override
  Future<void> create(DashboardLayout entity) async {
    logger.i('[DashboardLayoutHiveRepository] Creating dashboard layout with uuid ${entity.uuid}');
    if (_box.containsKey(entity.uuid)) {
      throw MobilerakerException('DashboardLayout with uuid ${entity.uuid} already exists! Please use update instead.');
    }
    entity.created = DateTime.now();
    entity.lastModified = entity.created;

    await _box.put(entity.uuid, entity);
  }

  @override
  Future<DashboardLayout> delete(String uuid) async {
    logger.i('[DashboardLayoutHiveRepository] Deleting dashboard layout with uuid $uuid');
    var e = await read(uuid: uuid);
    if (e == null) {
      throw MobilerakerException('DashboardLayout with uuid $uuid not found');
    }
    return e..delete();
  }

  @override
  Future<DashboardLayout?> read({String? uuid, int index = -1}) async {
    logger.i('[DashboardLayoutHiveRepository] Reading dashboard layout with uuid $uuid or index $index');
    assert(uuid != null || index >= 0, 'Either provide an uuid or an index >= 0');
    if (uuid != null) {
      return _box.get(uuid);
    } else {
      return _box.getAt(index);
    }
  }

  @override
  Future<void> update(DashboardLayout entity) async {
    logger.i('[DashboardLayoutHiveRepository] Updating dashboard layout with uuid ${entity.uuid}');
    if (!_box.containsKey(entity.uuid)) {
      throw MobilerakerException('DashboardLayout with uuid ${entity.uuid} does not exist! Please use create instead.');
    }
    await _box.put(entity.uuid, entity);
  }
}
