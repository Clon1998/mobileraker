/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import 'dashboard_component.dart';

part 'dashboard_tab.freezed.dart';
part 'dashboard_tab.g.dart';

@freezed
class DashboardTab with _$DashboardTab {
  static Map<String, IconData> availableIcons = {
    'settings': Icons.settings,
    'dashboard': Icons.dashboard,
    'info': Icons.info,
    'tach': FlutterIcons.tachometer_faw,
    'sliders': FlutterIcons.settings_oct,
    'printer': FlutterIcons.printer_3d_mco,
    'nozzle': FlutterIcons.printer_3d_nozzle_mco,
    'fan': FlutterIcons.fan_mco,
  };

  static String defaultIcon = 'dashboard';

  @HiveType(typeId: 9)
  const factory DashboardTab({
    @HiveField(0) required String uuid,
    @HiveField(1) required String name,
    @HiveField(2) required String icon,
    @HiveField(3) required List<DashboardComponent> components,
    @HiveField(4) @Default(1) int version,
  }) = _DashboardTab;

  const DashboardTab._();

  factory DashboardTab.fromJson(Map<String, dynamic> json) =>
      _$DashboardTabFromJson(json);

  // Factory constructor that generates UUID automatically (for backward compatibility)
  factory DashboardTab.create({
    required String name,
    required String icon,
    required List<DashboardComponent> components,
  }) {
    return DashboardTab(
      uuid: const Uuid().v4(),
      name: name,
      icon: icon,
      components: components,
    );
  }

  // Computed property from original class
  IconData get iconData => availableIcons[icon] ?? Icons.dashboard;

}
