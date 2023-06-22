/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:json_annotation/json_annotation.dart';

enum WebcamServiceType {
  @JsonValue('mjpegstreamer')
  mjpegStreamer(true),
  @JsonValue('mjpegstreamer-adaptive')
  mjpegStreamerAdaptive(true),
  @JsonValue('uv4l-mjpeg')
  uv4lMjpeg(true),
  @JsonValue('ipstream')
  ipStream(false),
  @JsonValue('hlsstream')
  hlsStream(false),
  @JsonValue('ipstream')
  ipSream(false),
  @JsonValue('webrtc-camerastreamer')
  webRtc(false),
  @JsonValue('unknown')
  unknown(false);

  final bool supported;

  const WebcamServiceType(this.supported);
}
