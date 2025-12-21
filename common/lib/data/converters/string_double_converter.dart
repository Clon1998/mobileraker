/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

class StringDoubleConverter extends JsonConverter<double, Object> {
  const StringDoubleConverter();

  @override
  double fromJson(Object json) {
    if (json is num) {
      return json.toDouble();
    }
    return double.parse(json as String);
  }

  @override
  Object toJson(double object) => object;
}
