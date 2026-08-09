/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'mjpeg_config.dart';
import 'mjpeg_manager.dart';

class AdaptiveMjpegManager implements MjpegManager {
  AdaptiveMjpegManager(this._dio, MjpegConfig config)
      : _uri = config.snapshotUri ??
            config.streamUri.replace(
              queryParameters: {'action': 'snapshot'},
            ),
        _timeout = config.timeout,
        targetFps = config.targetFps;

  final Duration _timeout;
  final int targetFps;
  final Dio _dio;
  final Uri _uri;
  final StreamController<MemoryImage> _mjpegStreamController = StreamController();

  bool _isActive = false;
  bool _isRequestInProgress = false;
  Timer? _timer;
  DateTime _lastRefresh = DateTime.now();

  @override
  Stream<MemoryImage> get jpegStream => _mjpegStreamController.stream;

  int get frameTimeInMicros => 1000000 ~/ targetFps;

  @override
  void start() {
    if (_isActive) {
      talker.warning('[AdaptiveMjpegManager] Already started, ignoring start request');
      return;
    }
    talker.info('[AdaptiveMjpegManager] Starting');
    _isActive = true;
    _scheduleNextFrame(Duration.zero);
  }

  void _scheduleNextFrame(Duration delay) {
    if (!_isActive) return;

    _timer?.cancel();
    _timer = Timer(delay, _fetchNextFrame);
  }

  Future<void> _fetchNextFrame() async {
    if (!_isActive || _isRequestInProgress) return;
    _isRequestInProgress = true;
    try {
      final fetchStartTime = DateTime.now();
      final response = await _dio.getUri(
        _uri.replace(
          queryParameters: {
            ..._uri.queryParameters,
            'cacheBust': fetchStartTime.millisecondsSinceEpoch.toString(),
          },
        ),
        options: Options(
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          responseType: ResponseType.bytes,
        ),
      );

      if (!_isActive || _mjpegStreamController.isClosed) return;

      if (response.data is Uint8List && _isCompleteJpeg(response.data)) {
        _mjpegStreamController.add(MemoryImage(response.data));
      } else {
        // Snapshot endpoints (e.g. the Snapmaker U1's) can be caught mid-write and return a
        // truncated file. Drop it rather than handing a broken image to the Image widget,
        // which would only surface as an uncatchable decode error and a flash on screen.
        talker.warning('[AdaptiveMjpegManager] Dropped incomplete/corrupt JPEG frame from $_uri');
      }

      // Calculate timing for next frame
      final now = DateTime.now();
      final timeSinceLastFrame = now.difference(_lastRefresh);
      final targetDelay = Duration(microseconds: frameTimeInMicros) - timeSinceLastFrame;

      // Schedule next frame, ensuring we don't go faster than target FPS
      _scheduleNextFrame(Duration(microseconds: max(0, targetDelay.inMicroseconds)));
      _lastRefresh = now;
    } on DioException catch (error, stack) {
      talker.warning('DioException while requesting MJPEG-Snapshot', error);

      if (!_mjpegStreamController.isClosed && _isActive) {
        _mjpegStreamController.addError(error, stack);
      }
    } finally {
      _isRequestInProgress = false;
    }
  }

  @override
  void stop() {
    talker.info('[AdaptiveMjpegManager] Stopping');
    _isActive = false;
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> dispose() async {
    talker.info('[AdaptiveMjpegManager] Disposing');
    stop();
    await _mjpegStreamController.close();
  }
}

// Jpeg Magic Numbers: https://www.file-recovery.com/jpg-signature-format.htm
bool _isCompleteJpeg(Uint8List bytes) {
  if (bytes.length < 4) return false;
  final startsWithSoi = bytes[0] == 0xFF && bytes[1] == 0xD8;
  final endsWithEoi = bytes[bytes.length - 2] == 0xFF && bytes[bytes.length - 1] == 0xD9;
  return startsWithSoi && endsWithEoi;
}
