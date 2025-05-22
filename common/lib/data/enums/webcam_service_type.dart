/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

enum WebcamServiceType {
  @JsonValue('mjpegstreamer')
  mjpegStreamer(true, false, true),
  @JsonValue('mjpegstreamer-adaptive')
  mjpegStreamerAdaptive(true, false, true),
  @JsonValue('uv4l-mjpeg')
  uv4lMjpeg(true, false, false),
  @JsonValue('ipstream')
  ipStream(false, false, false),
  @JsonValue('hlsstream')
  hlsStream(false, false, false),
  @JsonValue('ipstream')
  ipSream(false, false, false),
  @JsonValue('webrtc-camerastreamer')
  webRtcCamStreamer(true, true, false),
  @JsonValue('webrtc-go2rtc')
  webRtcGo2Rtc(true, true, false),
  @JsonValue('webrtc-mediamtx')
  webRtcMediaMtx(true, true, false),
  @JsonValue('webrtc-creality')
  webRtcCreality(true, true, false),
  // This is a special case to make it possible to show "Preview" in the UI
  @JsonValue('_MrPrev_')
  preview(true, true, false),
  @JsonValue('unknown')
  unknown(false, false, false);

  final bool supported;

  final bool forSupporters;

  // If the webcam service type is supported by the companion app to use it as a snapshot source for notifications
  final bool companionSupported;

  const WebcamServiceType(this.supported, this.forSupporters, this.companionSupported);

  static List<WebcamServiceType> renderedValues() => WebcamServiceType.values
      .where((element) => element != WebcamServiceType.preview && element != WebcamServiceType.unknown)
      .toList();
}
