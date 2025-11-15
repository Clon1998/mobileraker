/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_data_export.freezed.dart';
part 'app_data_export.g.dart';

@freezed
class AppDataExport with _$AppDataExport {
  const factory AppDataExport({
    required String version,
    required DateTime exportDate,
    required List<Machine> machines,
    required List<DashboardLayout> layouts,
  }) = _AppDataExport;



  factory AppDataExport.fromJson(Map<String, dynamic> json) =>
      _$AppDataExportFromJson(json);
}