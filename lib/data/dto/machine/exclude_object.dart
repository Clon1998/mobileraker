import 'package:flutter/foundation.dart';
import 'package:mobileraker/util/extensions/iterable_extension.dart';
import 'package:vector_math/vector_math.dart';

class ExcludeObject {
  String? currentObject;
  List<String> excludedObjects;
  List<ParsedObject> objects;

  bool get available => objects.isNotEmpty;

  List<ParsedObject> get canBeExcluded => objects
      .where((element) => !excludedObjects.contains(element.name))
      .toList();

  ExcludeObject(
      {this.currentObject,
      this.excludedObjects = const [],
      this.objects = const []});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExcludeObject &&
          runtimeType == other.runtimeType &&
          currentObject == other.currentObject &&
          listEquals(objects, other.objects) &&
          listEquals(excludedObjects, other.excludedObjects);

  @override
  int get hashCode =>
      currentObject.hashCode ^
      excludedObjects.hashIterable ^
      objects.hashIterable;

  @override
  String toString() {
    return 'ExcludeObject{currentObject: $currentObject, excludedObjects: $excludedObjects, objects: $objects}';
  }
}

class ParsedObject {
  String name;
  Vector2 center;
  List<Vector2> polygons;

  ParsedObject(
      {required this.name, required this.center, this.polygons = const []});

  ParsedObject.fromList(
      {required this.name,
      required List<double> center,
      List<List<double>> polygons = const []})
      : this.center = center.isEmpty ? Vector2.zero() : Vector2.array(center),
        this.polygons = polygons.isEmpty
            ? []
            : polygons.map((e) => Vector2.array(e)).toList();

  // ParsedObject.fromJson(Map<String, dynamic> json):
  // this.name = json['name'],
  // this.center = Vector2.array(json['center'],
  // this.polygons = (json['polygon']).map().toList());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedObject &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          center == other.center &&
          listEquals(polygons, other.polygons);

  @override
  int get hashCode =>
      name.hashCode ^ center.hashCode ^ polygons.hashIterable;

  @override
  String toString() {
    return 'ParsedObject{name: $name, center: $center, polygons: $polygons}';
  }
}
