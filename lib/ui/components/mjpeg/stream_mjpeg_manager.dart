/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'mjpeg_config.dart';
import 'mjpeg_manager.dart';

/// This Manager is for the normal MJPEG!
class StreamMjpegManager implements MjpegManager {
  StreamMjpegManager(this._dio, MjpegConfig config)
      : _uri = config.streamUri,
        _timeout = config.timeout;

  // Jpeg Magic Numbers: https://www.file-recovery.com/jpg-signature-format.htm
  static const _triggerPattern = 0xFF;
  static const _soi = 0xD8;
  static const _eoi = 0xD9;
  static const _lastByte = 0x00;

  final Dio _dio;

  final Uri _uri;

  final Duration _timeout;

  final BytesBuilder _byteBuffer = BytesBuilder();

  final StreamController<MemoryImage> _mjpegStreamController = StreamController();

  @override
  Stream<MemoryImage> get jpegStream => _mjpegStreamController.stream;

  CancelToken? _cancelToken;

  @override
  void stop() {
    logger.i('[StreamMjpegManager] stopped stream');
    _cancelToken?.cancel();
  }

  @override
  void start() async {
    stop(); // Stop previous stream if it is running
    logger.i('[StreamMjpegManager] started stream');
    try {
      _cancelToken = CancelToken();
      var response = await _dio.getUri(
        _uri,
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: _timeout,
          sendTimeout: _timeout,
        ),
      );

      ResponseBody responseBody = response.data;
      responseBody.stream.listen(_onData, onError: _onError, cancelOnError: true, onDone: () {
        logger.i('[StreamMjpegManager] TCP stream is DONE');
      });
    } on DioException catch (error, stack) {
      logger.w('[StreamMjpegManager] DioException while requesting MJPEG-Stream', error);

      if (!_mjpegStreamController.isClosed) {
        _mjpegStreamController.addError(error, stack);
      }
    }
  }

  void _sendImage(Uint8List bytes) {
    if (bytes.isNotEmpty && !_mjpegStreamController.isClosed) {
      _mjpegStreamController.add(MemoryImage(bytes));
    }
  }

  void _onData(List<int> byteChunk) {
    if (_byteBuffer.isNotEmpty && _lastByte == _triggerPattern) {
      if (byteChunk.first == _eoi) {
        _byteBuffer.addByte(byteChunk.first);

        _sendImage(_byteBuffer.takeBytes());
      }
    }

    for (var i = 0; i < byteChunk.length; i++) {
      final int cur = byteChunk[i];
      final int next = (i != byteChunk.length - 1) ? byteChunk[i + 1] : 0x00;

      if (cur == _triggerPattern && next == _soi) {
        // Detect start of JPEG
        _byteBuffer.addByte(_triggerPattern);
      } else if (_byteBuffer.isNotEmpty && cur == _triggerPattern && next == _eoi) {
        // Detect end of JPEG
        _byteBuffer.addByte(cur);
        _byteBuffer.addByte(next);
        _sendImage(_byteBuffer.takeBytes());
        i++;
      } else if (_byteBuffer.isNotEmpty) {
        // Prevent it from adding other than jpeg bytes
        _byteBuffer.addByte(cur);
      }
    }
  }

  void _onError(error, stack) {
    if (error case DioException(type: DioExceptionType.cancel)) {
      logger.i('[StreamMjpegManager] Stream was cancelled');
      return;
    }
    logger.e('[StreamMjpegManager] Error while streaming MJPEG', error, stack);

    if (!_mjpegStreamController.isClosed) {
      _mjpegStreamController.addError(error, stack);
    }
  }

  @override
  Future<void> dispose() async {
    _cancelToken?.cancel();
    _cancelToken = null;
    _mjpegStreamController.close();

    logger.i('StreamMjpegManager DISPOSED');
  }
}
