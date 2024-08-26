/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

enum WebcamServiceType {
  @JsonValue('mjpegstreamer')
  mjpegStreamer(true, false),
  @JsonValue('mjpegstreamer-adaptive')
  mjpegStreamerAdaptive(true, false),
  @JsonValue('uv4l-mjpeg')
  uv4lMjpeg(true, false),
  @JsonValue('ipstream')
  ipStream(false, false),
  @JsonValue('hlsstream')
  hlsStream(false, false),
  @JsonValue('ipstream')
  ipSream(false, false),
  @JsonValue('webrtc-camerastreamer')
  webRtcCamStreamer(true, true),
  @JsonValue('webrtc-go2rtc')
  webRtcGo2Rtc(true, true),
  @JsonValue('webrtc-mediamtx')
  webRtcMediaMtx(true, true),
  // This is a special case to make it possible to show "Preview" in the UI
  @JsonValue('_MrPrev_')
  preview(true, true),
  @JsonValue('unknown')
  unknown(false, false);

  final bool supported;

  final bool forSupporters;

  const WebcamServiceType(this.supported, this.forSupporters);

  static List<WebcamServiceType> renderedValues() => WebcamServiceType.values
      .where((element) => element != WebcamServiceType.preview && element != WebcamServiceType.unknown)
      .toList();
}
