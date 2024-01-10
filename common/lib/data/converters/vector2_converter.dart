/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';
import 'package:vector_math/vector_math.dart';

class Vector2Converter extends JsonConverter<Vector2, List<dynamic>?> {
  const Vector2Converter();

  @override
  Vector2 fromJson(List<dynamic>? json) {
    if (json == null || json.isEmpty) return Vector2.zero();

    var list = json.map((e) => (e as num).toDouble()).toList();
    return Vector2.array(list);
  }

  @override
  List<dynamic> toJson(Vector2 object) {
    var list = <double>[0, 0];
    object.copyIntoArray(list);
    return list.toList(growable: false);
  }
}
