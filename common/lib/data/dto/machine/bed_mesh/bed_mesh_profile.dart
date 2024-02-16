/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stringr/stringr.dart';

part 'bed_mesh_profile.freezed.dart';
part 'bed_mesh_profile.g.dart';

@freezed
class BedMeshProfile with _$BedMeshProfile {
  const BedMeshProfile._();

  @JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
  const factory BedMeshProfile({
    required String name,

    /// List of Z values. Outer list is X, inner list is Y, value is Z
    // @JsonKey(fromJson: _bedMeshPoints, readValue: _bedMeshPointsCords, includeToJson: false)
    // @Default([])
    // List<MeshPoint> points,

    @Default([]) List<List<double>> points,
    required BedMeshParams meshParams,
  }) = _BedMeshProfile;

  factory BedMeshProfile.fromJson(String name, Map<String, dynamic> json) =>
      _$BedMeshProfileFromJson({'name': name, ...json});

  double get valueRange {
    double min = double.infinity;
    double max = double.negativeInfinity;
    for (var z in points.flattened) {
      if (z < min) min = z;
      if (z > max) max = z;
    }

    if (min.isFinite && max.isFinite) {
      return max - min;
    }
    return 0;
  }
}

// "mesh_params": {
// "min_x": 40,
// "max_x": 260,
// "min_y": 40,
// "max_y": 260,
// "x_count": 5,
// "y_count": 5,
// "mesh_x_pps": 2,
// "mesh_y_pps": 2,
// "algo": "bicubic",
// "tension": 0.2
// }

@freezed
class BedMeshParams with _$BedMeshParams {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory BedMeshParams({
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required int xCount,
    required int yCount,
    @JsonKey(name: 'mesh_x_pps') required int meshXPPS,
    @JsonKey(name: 'mesh_y_pps') required int meshYPPS,
    required String algo,
    required double tension,
  }) = _BedMeshParams;

  factory BedMeshParams.fromJson(Map<String, dynamic> json) => _$BedMeshParamsFromJson(json);
}

class MeshPoint {
  final double x;
  final double y;
  final double z;

  MeshPoint(this.x, this.y, this.z);
}

// Required because kaka wants it like that
List<MeshPoint> _bedMeshPoints(List<MeshPoint> rawData) {
  return rawData;
}

List<MeshPoint> _bedMeshPointsCords(Map<dynamic, dynamic> json, String key) {
  var rawData = json[key] as List<dynamic>;

  var minX = json['mesh_params']['min_x'];
  var minY = json['mesh_params']['min_y'];
  var xDistance = (json['mesh_params']['max_x'] - minX) / (json['mesh_params']['x_count'] - 1);
  var yDistance = (json['mesh_params']['max_y'] - minY) / (json['mesh_params']['y_count'] - 1);

  return rawData
      .mapIndex((yList, yIndex) {
        yList as List;
        return yList.mapIndex((z, xIndex) {
          z as num;
          return MeshPoint(minX + xIndex * xDistance, minY + yIndex * yDistance, z.toDouble());
        });
      })
      .flattened
      .toList();
}
