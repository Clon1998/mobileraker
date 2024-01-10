/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/ui/components/mjpeg/stream_mjpeg_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'adaptive_mjpeg_manager.dart';
import 'mjpeg_config.dart';
import 'mjpeg_mode.dart';

part 'mjpeg_manager.g.dart';

abstract class MjpegManager {
  void start();

  void stop();

  void dispose();

  Stream<MemoryImage> get jpegStream;
}

@riverpod
MjpegManager mjpegManager(MjpegManagerRef ref, Dio dio, MjpegConfig config) {
  var manager = switch (config.mode) {
    MjpegMode.adaptiveStream => AdaptiveMjpegManager(dio, config),
    MjpegMode.stream => StreamMjpegManager(dio, config),
  };
  ref.onDispose(manager.dispose);
  return manager;
}
