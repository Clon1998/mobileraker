/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/enums/webcam_service_type.dart';
import 'package:uuid/uuid.dart';
import 'package:vector_math/vector_math_64.dart';

part 'webcam_info.g.dart';

final defaultStreamUri = Uri(path: '/webcam', query: 'action=stream');
final defaultSnapshotUri = Uri(path: '/webcam', query: 'action=snapshot');

// "1dec5e79-a49e-4742-a169-4abb68aee6a3": {
// "enabled": true, // fluidd only
// "flipX": true,
// "flipY": true,
// "name": "Default",
// "service": "ipstream",
// "targetFps": 15, !! "15" used by mainsail, fluidd uses number directly
// "targetFpsIdle": 15, // Used by fluidd for "Cam not in focus"
// "urlStream": "/webcam?action=stream",
// "rotation": 0, // fluidd key for rotation
// "rotate": 0, // Mainsail key for rotation
// "urlStream": "/webcam?action=stream", // Fluid and Mainsail
// "urlSnapshot": "/webcam?action=snapshot" // mansail only
// }

// NEW Webcam API - Moonraker
// CAM_FIELDS {
//   "name": "name",
//   "service": "service",
//   "target_fps": "targetFps",
//   "stream_url": "urlStream",
//   "snapshot_url": "urlSnapshot",
//   "flip_horizontal": "flipX",
//   "flip_vertical": "flipY",
//   "enabled": "enabled",
//   "target_fps_idle": "targetFpsIdle",
//   "aspect_ratio": "aspectRatio",
//   "icon": "icon",
//   "extra_data": {}
// }

/*

        webcam["name"] = cam_data["name"]
        webcam["enabled"] = cam_data.get("enabled", True)
        webcam["icon"] = cam_data.get("icon", "mdiWebcam")
        webcam["aspect_ratio"] = cam_data.get("aspectRatio", "4:3")
        webcam["location"] = cam_data.get("location", "printer")
        webcam["service"] = cam_data.get("service", "mjpegstreamer")
        webcam["target_fps"] = cam_data.get("targetFps", 15)
        webcam["target_fps_idle"] = cam_data.get("targetFpsIdle", 5)
        webcam["stream_url"] = cam_data.get("urlStream", "")
        webcam["snapshot_url"] = cam_data.get("urlSnapshot", "")
        webcam["flip_horizontal"] = cam_data.get("flipX", False)
        webcam["flip_vertical"] = cam_data.get("flipY", False)
        webcam["rotation"] = cam_data.get("rotation", webcam.get("rotate", 0))
        webcam["extra_data"] = cam_data.get("extra_data", {})

 */

@JsonSerializable()
class WebcamInfo {
  WebcamInfo(
      {required this.uuid,
      required this.name,
      required this.service,
      this.flipHorizontal = false,
      this.flipVertical = false,
      required this.streamUrl,
      required this.snapshotUrl,
    this.rotation = 0,
    this.targetFps = 15,
    this.enabled = true});

  factory WebcamInfo.mjpegDefault() {
    return WebcamInfo(
        uuid: const Uuid().v4(),
        name: 'Default',
        service: WebcamServiceType.mjpegStreamer,
        streamUrl: defaultStreamUri,
        snapshotUrl: defaultSnapshotUri);
  }

  factory WebcamInfo.fromJson(Map<String, dynamic> json) =>
      _$WebcamInfoFromJson(json);

  @JsonKey(required: true)
  final String uuid;
  @JsonKey(required: true)
  String name;
  @JsonKey(required: true, unknownEnumValue: WebcamServiceType.unknown)
  WebcamServiceType service;
  @JsonKey(name: 'flipX')
  bool flipHorizontal;
  @JsonKey(name: 'flipY')
  bool flipVertical;
  @JsonKey(name: 'urlStream')
  Uri streamUrl;
  @JsonKey(name: 'urlSnapshot', readValue: _snapshotOrStream)
  Uri snapshotUrl;
  @JsonKey(readValue: _rotateOrRotation)
  int rotation;
  @JsonKey()
  bool enabled;

  @JsonKey(fromJson: _wrappedInt)
  int targetFps;

  Matrix4 get transformMatrix => Matrix4.identity()
    ..rotateX(flipHorizontal ? pi : 0)
    ..rotateY(flipVertical ? pi : 0);

  WebcamInfo copyWith({
    String? name,
    WebcamServiceType? service,
    bool? flipHorizontal,
    bool? flipVertical,
    Uri? streamUrl,
    Uri? snapshotUrl,
    int? rotation,
    int? targetFps,
  }) {
    return WebcamInfo(
      uuid: uuid,
      name: name ?? this.name,
      service: service ?? this.service,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      streamUrl: streamUrl ?? this.streamUrl,
      snapshotUrl: snapshotUrl ?? this.snapshotUrl,
      rotation: rotation ?? this.rotation,
      targetFps: targetFps ?? this.targetFps,
    );
  }

  Map<String, dynamic> toJson() => _$WebcamInfoToJson(this);

  @override
  String toString() {
    return 'WebcamInfo{uuid: $uuid, name: $name, service: $service, flipHorizontal: $flipHorizontal, flipVertical: $flipVertical, streamUrl: $streamUrl, snapshotUrl: $snapshotUrl, rotation: $rotation, targetFps: $targetFps}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebcamInfo &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid &&
          name == other.name &&
          service == other.service &&
          flipHorizontal == other.flipHorizontal &&
          flipVertical == other.flipVertical &&
          streamUrl == other.streamUrl &&
          snapshotUrl == other.snapshotUrl &&
          rotation == other.rotation &&
          targetFps == other.targetFps;

  @override
  int get hashCode =>
      uuid.hashCode ^
      name.hashCode ^
      service.hashCode ^
      flipHorizontal.hashCode ^
      flipVertical.hashCode ^
      streamUrl.hashCode ^
      snapshotUrl.hashCode ^
      rotation.hashCode ^
      targetFps.hashCode;
}

String _snapshotOrStream(Map m, _) {
  if (m.containsKey('urlSnapshot')) {
    return m['urlSnapshot'];
  }
  return Uri.parse(m['urlStream']).replace(query: 'action=snapshot').toString();
}

int? _rotateOrRotation(Map m, _) {
  return m['rotate'] ?? m['rotation'];
}

int _wrappedInt(wrapped) {
  if (wrapped is int) {
    return wrapped;
  }
  return int.tryParse(wrapped) ?? 15;
}
