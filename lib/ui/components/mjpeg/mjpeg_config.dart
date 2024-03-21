/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

import 'mjpeg_mode.dart';

@immutable
class MjpegConfig {
  const MjpegConfig({
    required this.streamUri,
    required this.snapshotUri,
    required this.mode,
    this.targetFps = 10,
    this.timeout = const Duration(seconds: 10),
    this.rotation = 0,
    this.transformation,
  });

  final Uri streamUri;
  final Uri? snapshotUri;
  final Duration timeout;
  final int targetFps;
  final MjpegMode mode;
  final int rotation;
  final Matrix4? transformation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MjpegConfig &&
          runtimeType == other.runtimeType &&
          streamUri == other.streamUri &&
          snapshotUri == other.snapshotUri &&
          timeout == other.timeout &&
          targetFps == other.targetFps &&
          rotation == other.rotation &&
          transformation == other.transformation &&
          mode == other.mode;

  @override
  int get hashCode =>
      streamUri.hashCode ^
      snapshotUri.hashCode ^
      timeout.hashCode ^
      targetFps.hashCode ^
      rotation.hashCode ^
      transformation.hashCode ^
      mode.hashCode;
}

class MjpegConfigBuilder {
  Uri? streamUri;
  Uri? snapshotUri;
  Duration? timeout;
  Map<String, String>? httpHeader;
  int? targetFps;
  MjpegMode? mode;
  int? rotation;
  Matrix4? transformation;
  bool? trustSelfSignedCertificate;

  MjpegConfig build() {
    if (streamUri == null) {
      throw ArgumentError('StreamURI is null');
    }
    if (snapshotUri == null) {
      throw ArgumentError('snapshotUri is null');
    }
    if (mode == null) {
      throw ArgumentError('mode is null');
    }

    return MjpegConfig(
      streamUri: streamUri!,
      snapshotUri: snapshotUri!,
      mode: mode!,
      targetFps: targetFps ?? 10,
      timeout: timeout ?? const Duration(seconds: 10),
      rotation: rotation ?? 0,
      transformation: transformation,
    );
  }
}
