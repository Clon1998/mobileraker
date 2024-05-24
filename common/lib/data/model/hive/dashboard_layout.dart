/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'dashboard_layout.g.dart';

@HiveType(typeId: 12)
class DashboardLayout extends HiveObject {
  DashboardLayout._({
    required this.uuid,
    required this.created,
    required this.lastModified,
    required this.name,
    required this.tabs,
  });

  DashboardLayout({required this.name, required this.tabs});

  @HiveField(0)
  String uuid = const Uuid().v4();
  @HiveField(1)
  DateTime? created;
  @HiveField(2)
  DateTime? lastModified;

  @HiveField(3)
  String name;
  @HiveField(4)
  List<DashboardTab> tabs;

  @override
  Future<void> save() async {
    lastModified = DateTime.now();
    await super.save();
  }

  DashboardLayout copyWith({
    String? name,
    List<DashboardTab>? tabs,
  }) {
    return DashboardLayout._(
      uuid: uuid,
      created: created,
      lastModified: lastModified,
      name: name ?? this.name,
      tabs: tabs ?? this.tabs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardLayout &&
          runtimeType == other.runtimeType &&
          (identical(uuid, other.uuid) || uuid == other.uuid) &&
          (identical(name, other.name) || name == other.name) &&
          (identical(created, other.created) || created == other.created) &&
          (identical(lastModified, other.lastModified) || lastModified == other.lastModified) &&
          const DeepCollectionEquality().equals(tabs, other.tabs);

  @override
  int get hashCode => Object.hash(
        uuid,
        name,
        created,
        lastModified,
        const DeepCollectionEquality().hash(tabs),
      );

  @override
  String toString() {
    return 'DashboardLayout{uuid: $uuid, name: $name, tabs: $tabs}';
  }

  Map<String, dynamic> export() => {
        'version': 1,
        'name': name,
        'tabs': tabs.map((e) => e.export()).toList(),
      };
}
