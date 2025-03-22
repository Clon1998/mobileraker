/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
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

  // Smoothing factors
  final double _frameTimeSmoothing = 0.6;
  final double _requestTimeSmoothing = 0.1;

  // Smoothed values
  double _averageFrameTime = 0.0;
  double _averageRequestTime = 0.0;

  @override
  Stream<MemoryImage> get jpegStream => _mjpegStreamController.stream;

  int get frameTimeInMicros => 1000000 ~/ targetFps;

  @override
  void start() {
    if (_isActive) {
      logger.w('[AdaptiveMjpegManager] Already started, ignoring start request');
      return;
    }
    logger.i('[AdaptiveMjpegManager] Starting');
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

      if (response.data is Uint8List && response.data.isNotEmpty) {
        _mjpegStreamController.add(MemoryImage(response.data));
      }

      // Get current time
      final now = DateTime.now();

      // Calculate current frame time (time since last frame)
      final currentFrameTime = now.difference(_lastRefresh).inMicroseconds.toDouble();

      // Apply EMA to frame time
      if (_averageFrameTime > 0) {
        _averageFrameTime =
            (_averageFrameTime * _frameTimeSmoothing) + (currentFrameTime * (1.0 - _frameTimeSmoothing));
      } else {
        // First frame, initialize with current value
        _averageFrameTime = currentFrameTime;
      }

      // Calculate current request time (time it took to request and receive frame)
      final currentRequestTime = now.difference(fetchStartTime).inMicroseconds.toDouble();

      // Apply EMA to request time
      if (_averageRequestTime > 0) {
        _averageRequestTime =
            (_averageRequestTime * _requestTimeSmoothing) + (currentRequestTime * (1.0 - _requestTimeSmoothing));
      } else {
        // First request, initialize with current value
        _averageRequestTime = currentRequestTime;
      }

      // Calculate target delay based on smoothed request time
      final targetDelay =
          Duration(microseconds: frameTimeInMicros) - Duration(microseconds: _averageRequestTime.round());

      // Schedule next frame, ensuring we don't go faster than target FPS
      _scheduleNextFrame(Duration(microseconds: max(0, targetDelay.inMicroseconds)));

      // Update last refresh time
      _lastRefresh = now;
    } on DioException catch (error, stack) {
      logger.w('DioException while requesting MJPEG-Snapshot', error);

      if (!_mjpegStreamController.isClosed && _isActive) {
        _mjpegStreamController.addError(error, stack);
      }
    } finally {
      _isRequestInProgress = false;
    }
  }

  @override
  void stop() {
    logger.i('[AdaptiveMjpegManager] Stopping');
    _isActive = false;
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> dispose() async {
    logger.i('[AdaptiveMjpegManager] Disposing');
    stop();
    await _mjpegStreamController.close();
  }
}
