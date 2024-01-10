/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/converters/integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../enums/webcam_service_type.dart';

part 'webcam_info.freezed.dart';
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

/*
{
                "enabled": true,
                "icon": "mdiWebcam",
                "aspect_ratio": "4:3",
                "target_fps_idle": 5,
                "name": "Default",
                "location": "printer",
                "service": "mjpegstreamer-adaptive",
                "target_fps": 15,
                "stream_url": "/webcam/?action=stream",
                "snapshot_url": "/webcam/?action=snapshot",
                "flip_horizontal": false,
                "flip_vertical": false,
                "rotation": 180,
                "source": "database",
                "extra_data": {}
            },
 */

@freezed
class WebcamInfo with _$WebcamInfo {
  const WebcamInfo._();

  @JsonSerializable(
    fieldRename: FieldRename.snake,
  )
  const factory WebcamInfo({
    @JsonKey(includeToJson: false, readValue: _uuidReader) required String uuid,
    required String name,
    @JsonKey(unknownEnumValue: WebcamServiceType.unknown) required WebcamServiceType service,
    required Uri streamUrl,
    required Uri snapshotUrl,
    @Default(false) @JsonKey(fromJson: _boolOrInt) bool enabled,
    @Default('') String icon,
    @Default('4:4') String aspectRatio,
    @Default(5) @IntegerConverter() int targetFpsIdle,
    @Default('unknown') String location,
    @IntegerConverter() @Default(15) int targetFps,
    @JsonKey(fromJson: _boolOrInt) @Default(false) bool flipHorizontal,
    @JsonKey(fromJson: _boolOrInt) @Default(false) bool flipVertical,
    @IntegerConverter() @Default(0) int rotation,
    @Default('unknown') String source,
  }) = _WebcamInfo;

  factory WebcamInfo.fromJson(Map<String, dynamic> json) => _$WebcamInfoFromJson(json);

  factory WebcamInfo.mjpegDefault() {
    return WebcamInfo(
        uuid: '',
        name: 'Default',
        service: WebcamServiceType.mjpegStreamer,
        streamUrl: defaultStreamUri,
        snapshotUrl: defaultSnapshotUri);
  }

  Matrix4 get transformMatrix => Matrix4.identity()
    ..rotateX(flipVertical ? pi : 0)
    ..rotateY(flipHorizontal ? pi : 0);

  bool get isReadOnly => source == 'config';
}

bool _boolOrInt(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw == 1;
  return false;
}

String _uuidReader(Map input, String key) {
  if (input.containsKey(key)) {
    return input[key] as String;
  }
  return input['name'] as String;
}
