/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_roots.freezed.dart';
part 'file_roots.g.dart';

// {
// "name": "config",
// "path": "/home/pi/printer_data/config",
// "permissions": "rw"
// },

@freezed
sealed class FileRoot with _$FileRoot {
  const factory FileRoot({
    required String name,
    required String path,
    String? permissions,
  }) = _FileRoot;

  factory FileRoot.fromJson(Map<String, dynamic> json) => _$FileRootFromJson(json);
}
