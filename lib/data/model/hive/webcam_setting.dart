/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/data/model/hive/webcam_rotation.dart';
import 'package:uuid/uuid.dart';

import 'webcam_mode.dart';

part 'webcam_setting.g.dart';

@HiveType(typeId: 2)
class WebcamSetting {
  @HiveField(0)
  String name;
  @HiveField(1)
  String uuid = const Uuid().v4();
  @HiveField(2)
  String url;
  @HiveField(3)
  bool flipHorizontal = false;
  @HiveField(4)
  bool flipVertical = false;
  @HiveField(5, defaultValue: 15)
  int targetFps = 15;
  @HiveField(6, defaultValue: WebCamMode.ADAPTIVE_STREAM)
  WebCamMode mode = WebCamMode.ADAPTIVE_STREAM;
  @HiveField(7, defaultValue: WebCamRotation.landscape)
  WebCamRotation rotate = WebCamRotation.landscape;

  WebcamSetting(this.name, this.url);

  double get yTransformation {
    if (flipVertical) {
      return pi;
    } else {
      return 0;
    }
  }

  double get xTransformation {
    if (flipHorizontal) {
      return pi;
    } else {
      return 0;
    }
  }

  Matrix4 get transformMatrix => Matrix4.identity()
    ..rotateX(xTransformation)
    ..rotateY(yTransformation);

  @override
  String toString() {
    return 'WebcamSetting{name: $name, uuid: $uuid, url: $url, flipHorizontal: $flipHorizontal, flipVertical: $flipVertical, targetFps: $targetFps, mode: $mode, rotate:$rotate}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebcamSetting &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          uuid == other.uuid &&
          url == other.url &&
          flipHorizontal == other.flipHorizontal &&
          flipVertical == other.flipVertical &&
          targetFps == other.targetFps &&
          mode == other.mode &&
          rotate == other.rotate;

  @override
  int get hashCode =>
      name.hashCode ^
      uuid.hashCode ^
      url.hashCode ^
      flipHorizontal.hashCode ^
      flipVertical.hashCode ^
      targetFps.hashCode ^
      mode.hashCode ^
      rotate.hashCode;
}
