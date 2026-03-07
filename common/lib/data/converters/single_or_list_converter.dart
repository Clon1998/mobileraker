/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

class SingleOrListConverter<T> implements JsonConverter<List<T>, Object?> {
  const SingleOrListConverter(this._fromJson);

  final T Function(Object?) _fromJson;

  @override
  List<T> fromJson(Object? json) {
    if (json == null) return [];
    if (json is List) return json.map(_fromJson).toList();
    return [_fromJson(json)]; // wrap single value
  }

  @override
  Object? toJson(List<T> list) => list.length == 1 ? list.first : list;
}