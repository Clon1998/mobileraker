/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vector_math/vector_math.dart';

import '../../converters/vector2_converter.dart';

part 'exclude_object.freezed.dart';
part 'exclude_object.g.dart';

@freezed
class ExcludeObject with _$ExcludeObject {
  const ExcludeObject._();

  @JsonSerializable(explicitToJson: true)
  const factory ExcludeObject({
    @JsonKey(name: 'current_object') String? currentObject,
    @JsonKey(name: 'excluded_objects')
    @Default([])
        List<String> excludedObjects,
    @JsonKey() @Default([]) List<ParsedObject> objects,
  }) = _ExcludeObject;

  factory ExcludeObject.fromJson(Map<String, dynamic> json) =>
      _$ExcludeObjectFromJson(json);

  factory ExcludeObject.partialUpdate(
      ExcludeObject? current, Map<String, dynamic> partialJson) {
    ExcludeObject old = current ?? const ExcludeObject();
    var mergedJson = {...old.toJson(), ...partialJson};

    return ExcludeObject.fromJson(mergedJson);
  }

  bool get available => objects.isNotEmpty;

  List<ParsedObject> get canBeExcluded => objects
      .where((element) => !excludedObjects.contains(element.name))
      .toList();
}

@freezed
class ParsedObject with _$ParsedObject {
  const factory ParsedObject({
    required String name,
    @Vector2Converter() required Vector2 center,
    @Vector2Converter()
    @JsonKey(name: 'polygon')
    @Default([])
    List<Vector2> polygons,
  }) = _ParsedObject;

  factory ParsedObject.fromJson(Map<String, dynamic> json) =>
      _$ParsedObjectFromJson(json);
}
