/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'dashboard_component.dart';

part 'dashboard_tab.g.dart';

@HiveType(typeId: 9)
class DashboardTab extends HiveObject {
  DashboardTab({
    required this.name,
    required this.icon,
    required this.components,
  });

  DashboardTab._({
    required this.uuid,
    required this.name,
    required this.icon,
    required this.components,
  });

  @HiveField(0)
  String uuid = const Uuid().v4();
  @HiveField(1)
  String name;
  @HiveField(2)
  String icon;
  @HiveField(3)
  List<DashboardComponent> components;

  DashboardTab copyWith({
    String? name,
    String? icon,
    List<DashboardComponent>? components,
  }) {
    return DashboardTab._(
      uuid: uuid,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      components: components ?? this.components,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardTab &&
          runtimeType == other.runtimeType &&
          (identical(uuid, other.uuid) || uuid == other.uuid) &&
          (identical(name, other.name) || name == other.name) &&
          (identical(icon, other.icon) || icon == other.icon) &&
          const DeepCollectionEquality().equals(components, other.components);

  @override
  int get hashCode => Object.hash(
        uuid,
        name,
        icon,
        const DeepCollectionEquality().hash(components),
      );

  @override
  String toString() {
    return 'DashboardTab{uuid: $uuid, name: $name, components: $components}';
  }
}
