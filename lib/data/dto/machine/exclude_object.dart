import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vector_math/vector_math.dart';

part 'exclude_object.freezed.dart';

@freezed
class ExcludeObject with _$ExcludeObject {
  const ExcludeObject._();

  const factory ExcludeObject({
    String? currentObject,
    @Default([]) List<String> excludedObjects,
    @Default([]) List<ParsedObject> objects,
  }) = _ExcludeObject;

  bool get available => objects.isNotEmpty;

  List<ParsedObject> get canBeExcluded => objects
      .where((element) => !excludedObjects.contains(element.name))
      .toList();
}

@freezed
class ParsedObject with _$ParsedObject {
  const factory ParsedObject({
    required String name,
    required Vector2 center,
    @Default([]) List<Vector2> polygons,
  }) = _ParsedObject;
}
