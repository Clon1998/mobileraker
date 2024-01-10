/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

class UnixDateTimeConverter extends JsonConverter<DateTime, num> {
  const UnixDateTimeConverter();

  @override
  DateTime fromJson(num json) => DateTime.fromMillisecondsSinceEpoch((json * 1000).toInt());

  @override
  num toJson(DateTime object) => object.millisecondsSinceEpoch / 1000;
}
