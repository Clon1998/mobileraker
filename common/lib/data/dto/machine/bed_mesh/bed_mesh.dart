/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'bed_mesh_profile.dart';

part 'bed_mesh.freezed.dart';
part 'bed_mesh.g.dart';

@freezed
class BedMesh with _$BedMesh {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory BedMesh({
    @JsonKey(readValue: _profileName) String? profileName,
    @JsonKey(readValue: _readMinX) @Default(0) double minX,
    @JsonKey(readValue: _readMinY) @Default(0) double minY,
    @JsonKey(readValue: _readMaxX) @Default(0) double maxX,
    @JsonKey(readValue: _readMaxY) @Default(0) double maxY,

    /// Same as probed in profiles
    @Default([]) List<List<double>> probedMatrix,

    /// The Calculated Mesh based on the probed values
    @Default([]) List<List<double>> meshMatrix,
    @JsonKey(fromJson: _parseProfiles) @Default([]) List<BedMeshProfile> profiles,
  }) = _BedMesh;

  factory BedMesh.fromJson(Map<String, dynamic> json) => _$BedMeshFromJson(json);

  factory BedMesh.partialUpdate(BedMesh? current, Map<String, dynamic> partialJson) {
    BedMesh old = current ?? const BedMesh();
    var mergedJson = {...old.toJson(), ...partialJson};
    return BedMesh.fromJson(mergedJson);
  }
}

List<BedMeshProfile> _parseProfiles(Map raw) {
  return raw.entries.map((e) {
    String name = e.key;
    Map<String, dynamic> value = (e.value as Map).map((key, value) => MapEntry(key as String, value));

    return BedMeshProfile.fromJson(name, value);
  }).toList();
}

dynamic _readMinX(Map raw, _) {
  return _saveMinMaxExtraction(raw['mesh_min'], 0);
}

dynamic _readMinY(Map raw, _) {
  return _saveMinMaxExtraction(raw['mesh_min'], 1);
}

dynamic _readMaxX(Map raw, _) {
  return _saveMinMaxExtraction(raw['mesh_max'], 0);
}

dynamic _readMaxY(Map raw, _) {
  return _saveMinMaxExtraction(raw['mesh_max'], 1);
}

String? _profileName(Map raw, _) {
  String name = raw['profile_name'];
  return (name.isEmpty) ? null : name;
}

dynamic _saveMinMaxExtraction(List? mesh, int index) {
  if (mesh == null || mesh.length < index + 1) return null;

  return mesh[index];
}
