/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'mjpeg_config.dart';
import 'mjpeg_manager.dart';

/// Manager for an Adaptive MJPEG, using snapshots/images of the MJPEG provider!
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

  bool active = false;

  DateTime lastRefresh = DateTime.now();

  Timer? _timer;

  final int _retryCount = 0;

  @override
  Stream<MemoryImage> get jpegStream => _mjpegStreamController.stream;

  int get frameTimeInMillis {
    return 1000 ~/ targetFps;
  }

  @override
  void start() {
    active = true;
    logger.i('AdaptiveMjpegManager started - targFps: $targetFps - ${_uri.obfuscate()}');
    if (_timer?.isActive ?? false) return;
    _timer = Timer(const Duration(milliseconds: 0), _timerCallback);
  }

  @override
  void stop() {
    logger.i('AdaptiveMjpegManager Stopped MJPEG');
    active = false;
    _timer?.cancel();
  }

  _timerCallback() async {
    // logger.i('TimerTask ${DateTime.now()}');
    try {
      var response = await _dio.getUri(
        _uri.replace(
          queryParameters: {
            ..._uri.queryParameters,
            'cacheBust': lastRefresh.millisecondsSinceEpoch.toString(),
          },
        ),
        options: Options(
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          responseType: ResponseType.bytes,
        ),
      );

      _sendImage(response.data);
      _restartTimer();
    } on DioException catch (error, stack) {
      logger.w('DioException while requesting MJPEG-Snapshot', error);
      // we ignore those errors in case play/pause is triggers
      if (!_mjpegStreamController.isClosed) {
        _mjpegStreamController.addError(error, stack);
      }
    }
  }

  _restartTimer([DateTime? stamp]) {
    stamp ??= DateTime.now();
    if (!active) return;
    int diff = stamp.difference(lastRefresh).inMilliseconds;
    int calcTimeoutMillis = frameTimeInMillis - diff;
    // logger.i('Diff: $diff\n     CalcTi: $calcTimeoutMillis');
    _timer = Timer(
      Duration(milliseconds: max(0, calcTimeoutMillis)),
      _timerCallback,
    );
    lastRefresh = stamp;
  }

  _sendImage(Uint8List bytes) {
    if (bytes.isNotEmpty && !_mjpegStreamController.isClosed && active) {
      _mjpegStreamController.add(MemoryImage(bytes));
    }
  }

  @override
  Future<void> dispose() async {
    stop();
    _mjpegStreamController.close();
    logger.i('_AdaptiveStreamManager DISPOSED');
  }
}
