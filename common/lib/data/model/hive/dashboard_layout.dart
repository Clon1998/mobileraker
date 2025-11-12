/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'dashboard_layout.freezed.dart';
part 'dashboard_layout.g.dart';

@freezed
class DashboardLayout with _$DashboardLayout {
  @HiveType(typeId: 12)
  const factory DashboardLayout({
    @HiveField(0) required String uuid,
    @HiveField(1) DateTime? created,
    @HiveField(2) DateTime? lastModified,
    @HiveField(3) required String name,
    @HiveField(4) required List<DashboardTab> tabs,
    @HiveField(5) @Default(1) int version,
  }) = _DashboardLayout;

  const DashboardLayout._();

  factory DashboardLayout.fromJson(Map<String, dynamic> json) =>
      _$DashboardLayoutFromJson(json);

  // Factory constructor that generates UUID automatically (for backward compatibility)
  factory DashboardLayout.create({
    required String name,
    required List<DashboardTab> tabs,
  }) {
    return DashboardLayout(
      uuid: const Uuid().v4(),
      name: name,
      tabs: tabs,
    );
  }
}
