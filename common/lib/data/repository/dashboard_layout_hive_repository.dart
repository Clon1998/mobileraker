/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:hive_ce/hive.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../util/logger.dart';
import 'dashboard_layout_repository.dart';

part 'dashboard_layout_hive_repository.g.dart';

@Riverpod(keepAlive: true)
DashboardLayoutHiveRepository dashboardLayoutHiveRepository(Ref ref) {
  return DashboardLayoutHiveRepository();
}

class DashboardLayoutHiveRepository implements DashboardLayoutRepository {
  DashboardLayoutHiveRepository() : _box = Hive.box<DashboardLayout>('dashboard_layouts');

  final Box<DashboardLayout> _box;

  @override
  Future<List<DashboardLayout>> all() async {
    talker.info('[DashboardLayoutHiveRepository] Fetching all dashboard layouts');
    return _box.values.toList(growable: false);
  }

  @override
  Future<int> count() async {
    talker.info('[DashboardLayoutHiveRepository] Counting all dashboard layouts');
    return _box.length;
  }

  @override
  Future<void> create(DashboardLayout entity) async {
    if (entity.uuid == 'default') {
      throw MobilerakerException('Cannot create dashboard layout with reserved uuid "default"');
    }

    talker.info('[DashboardLayoutHiveRepository] Creating dashboard layout with uuid ${entity.uuid}');
    if (_box.containsKey(entity.uuid)) {
      throw MobilerakerException('DashboardLayout with uuid ${entity.uuid} already exists! Please use update instead.');
    }
    final dateTime = DateTime.now();
    await _box.put(entity.uuid, entity.copyWith(created: dateTime, lastModified: dateTime));
  }

  @override
  Future<DashboardLayout> delete(String uuid) async {
    talker.info('[DashboardLayoutHiveRepository] Deleting dashboard layout with uuid $uuid');
    var e = await read(id: uuid);
    if (e == null) {
      throw MobilerakerException('DashboardLayout with uuid $uuid not found');
    }

    await _box.delete(uuid);

    return e;
  }

  @override
  Future<DashboardLayout?> read({String? id, int index = -1}) async {
    talker.info('[DashboardLayoutHiveRepository] Reading dashboard layout with uuid $id or index $index');
    assert(id != null || index >= 0, 'Either provide an uuid or an index >= 0');
    if (id != null) {
      return _box.get(id);
    } else {
      return _box.getAt(index);
    }
  }

  @override
  Future<void> update(DashboardLayout entity) async {
    if (entity.uuid == 'default') {
      throw MobilerakerException('Cannot create dashboard layout with reserved uuid "default"');
    }
    talker.info('[DashboardLayoutHiveRepository] Updating dashboard layout with uuid ${entity.uuid}');
    if (!_box.containsKey(entity.uuid)) {
      throw MobilerakerException('DashboardLayout with uuid ${entity.uuid} does not exist! Please use create instead.');
    }
    await _box.put(entity.uuid, entity);
  }
}
