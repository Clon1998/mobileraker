/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

class IntegerConverter extends JsonConverter<int, num> {
  const IntegerConverter();

  @override
  int fromJson(num json) => json.toInt();

  @override
  num toJson(int object) => object;
}
