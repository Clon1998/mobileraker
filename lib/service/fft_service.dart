/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:common/util/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';

import '../util/spectrum_analyzer.dart';

class FftService {
  FftService() {
    IsolateNameServer.removePortNameMapping(_uiPort);
    IsolateNameServer.registerPortWithName(_receivePort.sendPort, _uiPort);
    _receivePort.listen(_onIsolateMessage);
  }

  static int maxDetectedFrequency = 300;
  static int sampleRate = 44100;
  static const String _uiPort = 'fftService/ui'; // Receive port for UI

  final FlutterAudioCapture _capture = FlutterAudioCapture();
  final ReceivePort _receivePort = ReceivePort();
  final StreamController<int> _peakFrequencyController = StreamController<int>();

  SendPort? _sendPort;

  Stream<int> get peakFrequencyStream => _peakFrequencyController.stream;

  Isolate? _isolate;

  start() async {
    var token = RootIsolateToken.instance!;
    _isolate?.kill();
    _isolate = await Isolate.spawn(_isolateSpawn, token);
    var res = await _capture.init();
    talker.info('Initialized capture reported init-state: $res');

    _capture.start(
      (e) {
        // talker.info('Received data from capturer: ${e.runtimeType}: ${e.length}');
        MicData micData;
        if (e is MicData) {
          micData = e;
        } else {
          throw ArgumentError('Unknown data type: ${e.runtimeType}');
        }
        var actualSampleRate = _capture.actualSampleRate;
        // talker.info('Actual sample rate: $actualSampleRate');
        if (_sendPort == null) return;
        if (actualSampleRate == null) {
          talker.warning('Sample rate is null, try again on next chunk');
          return;
        }
        _sendPort!.send(_MicDataMessage(micData, actualSampleRate));
      },
      (e) {
        talker.warning('Error in capturer', e);
      },
      sampleRate: sampleRate,
    );
  }

  stop() {
    _capture.stop();
    _isolate?.kill();
  }

  _onIsolateMessage(dynamic message) {
    // talker.info('Received message from isolate: $message');
    if (message is SendPort) {
      _sendPort = message;
    } else if (message is _PeakFrequencyMessage) {
      // talker.info('Received peak frequency from isolate: ${message.frequency}');
      _peakFrequencyController.add(message.frequency);
    }
  }

  static void _isolateSpawn(RootIsolateToken token) {
    _FFTIsolate(token);
  }

  void dispose() {
    _capture.stop();
    _peakFrequencyController.close();
    _receivePort.close();
    _isolate?.kill();
    talker.info('Stopped FFT service, killed isolate');
  }
}

class _FFTIsolate {
  _FFTIsolate(RootIsolateToken token) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    _init();
  }

  final ReceivePort _receivePort = ReceivePort();
  final SendPort _sendPort = IsolateNameServer.lookupPortByName(FftService._uiPort)!;

  SpectrumAnalyzer? _analyzer;

  Future<void> _init() async {
    await setupIsolateLogger();
    _sendPort.send(_receivePort.sendPort);

    _receivePort.listen(_onUiMessage);
  }

  void _onUiMessage(dynamic message) {
    // talker.info('Received message from UI: $message');
    if (message is! _MicDataMessage) return;
    if (_analyzer == null) {
      _analyzer ??= SpectrumAnalyzer(message.sampleRate);
      _analyzer!.peakFrequencyStream.listen((event) {
        _sendPort.send(_PeakFrequencyMessage(event));
      });
    }

    _analyzer!.submit(message.data);
  }
}

@immutable
sealed class _IsolateMessage {}

@immutable
class _MicDataMessage extends _IsolateMessage {
  _MicDataMessage(this.data, this.sampleRate);

  final double sampleRate;
  final MicData data;

  @override
  String toString() {
    return '_MicDataMessage{sampleRate: $sampleRate, data.length: ${data.length}}';
  }
}

@immutable
class _PeakFrequencyMessage extends _IsolateMessage {
  _PeakFrequencyMessage(this.frequency);

  final int frequency;
}
