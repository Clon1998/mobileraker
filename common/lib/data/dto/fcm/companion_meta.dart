/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'companion_meta.freezed.dart';
part 'companion_meta.g.dart';

@freezed
class CompanionMetaData with _$CompanionMetaData {
  const factory CompanionMetaData({
    required String version,
    required DateTime lastSeen,
  }) = _CompanionMetaData;

  factory CompanionMetaData.fromJson(Map<String, dynamic> json) =>
      _$CompanionMetaDataFromJson(json);
}
