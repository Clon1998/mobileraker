/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'dashboard_component.freezed.dart';
part 'dashboard_component.g.dart';

@freezed
class DashboardComponent with _$DashboardComponent {
  @HiveType(typeId: 10)
  const factory DashboardComponent({
    @HiveField(0) required String uuid,
    @HiveField(1) required DashboardComponentType type,
    @HiveField(2) @Default(true) bool showWhilePrinting,
    @HiveField(3) @Default(false) bool showBeforePrinterReady,
    @HiveField(5) @Default(1) int version,
  }) = _DashboardComponent;

  const DashboardComponent._();

  factory DashboardComponent.fromJson(Map<String, dynamic> json) =>
      _$DashboardComponentFromJson(json);

  // Factory constructor that generates UUID automatically (for backward compatibility)
  factory DashboardComponent.create({
    required DashboardComponentType type,
    bool showWhilePrinting = true,
    bool showBeforePrinterReady = false,
  }) {
    return DashboardComponent(
      uuid: const Uuid().v4(),
      type: type,
      showWhilePrinting: showWhilePrinting,
      showBeforePrinterReady: showBeforePrinterReady,
    );
  }
}
