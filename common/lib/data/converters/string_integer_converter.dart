/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

class StringIntegerConverter extends JsonConverter<int, Object> {
  const StringIntegerConverter();

  @override
  int fromJson(Object json) {
    if (json is num) {
      return json.toInt();
    }
    return int.parse(json as String);
  }

  @override
  Object toJson(int object) => object;
}
