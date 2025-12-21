/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../converters/unix_datetime_converter.dart';
import '../../enums/sort_kind_enum.dart';

part 'history_params.freezed.dart';
part 'history_params.g.dart';

@freezed
class HistoryParams with _$HistoryParams {
  @StringIntegerConverter()
  const factory HistoryParams({
    required int start, // Record number to start from (i.e. 10 would start at the 10th print)
    required int limit, // Maximum Number of prints to return (default: 50)
    @UnixDateTimeConverter() required DateTime? since, // All jobs after this UNIX timestamp
    @UnixDateTimeConverter() required DateTime? before, // All jobs before this UNIX timestamp
    required SortKind order, // Define return order asc or desc (default)
  }) = _HistoryParams;

  factory HistoryParams.fromJson(Map<String, dynamic> json) => _$HistoryParamsFromJson(json);
}
