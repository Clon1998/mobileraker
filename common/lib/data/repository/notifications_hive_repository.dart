/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/notification.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'notifications_repository.dart';

part 'notifications_hive_repository.g.dart';

@Riverpod(keepAlive: true)
NotificationsRepository notificationRepository(NotificationRepositoryRef ref) => NotificationsHiveRepository();

class NotificationsHiveRepository extends NotificationsRepository {
  NotificationsHiveRepository() : _box = Hive.box<Notification>('notifications');

  final Box<Notification> _box;

  @override
  Future<Notification?> getByMachineUuid(String machineId) async {
    return _box.get(machineId);
  }

  @override
  Future<void> save(Notification notification) {
    return _box.put(notification.machineUuid, notification);
  }
}
