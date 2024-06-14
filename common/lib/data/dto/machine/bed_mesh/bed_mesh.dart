/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'bed_mesh_profile.dart';

part 'bed_mesh.freezed.dart';
part 'bed_mesh.g.dart';

@freezed
class BedMesh with _$BedMesh {
  const BedMesh._();

  @JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
  const factory BedMesh({
    @JsonKey(readValue: _profileName) String? profileName,
    @Default((0, 0))
    @JsonKey(readValue: _readCord, fromJson: _bypass, toJson: _writeMeshCords)
    (double, double) meshMin,
    @Default((0, 0))
    @JsonKey(readValue: _readCord, fromJson: _bypass, toJson: _writeMeshCords)
    (double, double) meshMax,
    @Default([]) List<List<double>> probedMatrix, // Same as probed in profiles
    @Default([]) List<List<double>> meshMatrix, // The Calculated Mesh based on the probed values
    @JsonKey(fromJson: _parseProfiles, toJson: _deparseProfiles) @Default([]) List<BedMeshProfile> profiles,
  }) = _BedMesh;

  factory BedMesh.fromJson(Map<String, dynamic> json) => _$BedMeshFromJson(json);

  factory BedMesh.partialUpdate(BedMesh? current, Map<String, dynamic> partialJson) {
    BedMesh old = current ?? const BedMesh();
    var mergedJson = {...old.toJson(), ...partialJson};
    return BedMesh.fromJson(mergedJson);
  }

  double get xAxisSize => meshMax.$1 - meshMin.$1;

  double get yAxisSize => meshMax.$2 - meshMin.$2;

  (double, double) get zValueRangeProbed => _extractMaxMin(probedMatrix);

  (double, double) get zValueRangeMesh => _extractMaxMin(meshMatrix);

  List<List<double>> get meshCoordinates {
    List<List<double>> matrix = meshMatrix;
    return _transformToCords(matrix);
  }

  List<List<double>> get probedCoordinates {
    List<List<double>> matrix = probedMatrix;
    return _transformToCords(matrix);
  }

  List<List<double>> _transformToCords(List<List<double>> matrix) {
    if (matrix.isEmpty) {
      return List.empty();
    }
    var xCount = matrix[0].length;
    var yCount = matrix.length;

    var xStep = (xAxisSize) / (xCount - 1);
    var yStep = (yAxisSize) / (yCount - 1);

    var data = <List<double>>[];
    var yIndex = 0;
    for (var row in matrix) {
      var xIndex = 0;
      for (var value in row) {
        data.add([meshMin.$1 + xStep * xIndex, meshMin.$2 + yStep * yIndex, value]);
        xIndex++;
      }
      yIndex++;
    }

    return data;
  }

  (double, double) _extractMaxMin(List<List<double>> matrix) {
    double min = double.infinity;
    double max = double.negativeInfinity;
    for (var z in matrix.flattened) {
      if (z < min) min = z;
      if (z > max) max = z;
    }

    if (min.isFinite && max.isFinite) {
      return (min, max);
    }
    return (0, 0);
  }
}

List<BedMeshProfile> _parseProfiles(Map raw) {
  return raw.entries
      .map((e) {
        String name = e.key;
        Map<String, dynamic> value = (e.value as Map).map((key, value) => MapEntry(key as String, value));

        // sort the entires by name ignoring case
        return BedMeshProfile.fromJson(name, value);
      })
      .sorted((a, b) => compareAsciiLowerCaseNatural(a.name, b.name))
      // .sortedBy((element) => element.name.toLowerCase())
      .toList();
}

Map _deparseProfiles(List<BedMeshProfile> profiles) {
  return {
    for (var profile in profiles) profile.name: profile.toJson(),
  };
}

String? _profileName(Map raw, _) {
  String? name = raw['profile_name'];
  return (name?.isEmpty == false) ? name : null;
}

(double, double)? _readCord(Map raw, String key) {
  var cord = (raw[key] as List?);
  return _extractCords(cord);
}

(double, double)? _extractCords(List? cord) {
  if (cord == null || cord.length < 2) return null;

  var x = (cord[0] as num?)?.toDouble();
  var y = (cord[1] as num?)?.toDouble();

  return (x == null || y == null) ? null : (x, y);
}

// Helper function to bypass the type system since freezed is kinda meh with records....
(double, double) _bypass(dynamic e) => e ?? (0, 0);

dynamic _writeMeshCords((double, double)? cord) {
  if (cord == null) return null;

  return [cord.$1, cord.$2];
}
