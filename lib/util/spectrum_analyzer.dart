/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:common/util/logger.dart';
import 'package:fftea/fftea.dart';

import '../service/fft_service.dart';

typedef MicData = Float32List;

class SpectrumAnalyzer {
  SpectrumAnalyzer(this._sampleRate, [int? maxDetectedFrequency]) {
    this.maxDetectedFrequency = maxDetectedFrequency ?? FftService.maxDetectedFrequency;

    // Based on the sampleRate, we can calculate the required fftSize to get a bucket size of around 1Hz
    // The bucket size is calculated by sampleRate / fftSize
    // So if we want a bucket size of 1Hz, we need to have a fftSize of sampleRate / 1
    // This is the same as sampleRate / sampleRate
    fftSize = pow(2, (log(_sampleRate) / ln2).ceil()).toInt();
    _buffer = Float32List(fftSize);

    _fft = FFT(fftSize);
    maxBucketIndex = min(fftSize - 1, (this.maxDetectedFrequency * fftSize / _sampleRate).ceil());

    logger.i('Created bucketer with fftSize: $fftSize, maxBucketIndex: $maxBucketIndex for sampleRate: $_sampleRate');
  }

  late final int maxDetectedFrequency;
  late final int fftSize;
  late final int maxBucketIndex;

  final StreamController<int> _peakFrequencyController = StreamController<int>();

  Stream<int> get peakFrequencyStream => _peakFrequencyController.stream;

  final double _sampleRate;
  late final Float32List _buffer;
  late final FFT _fft;

  // We need to keep track of items in the buffer, since the buffer does not do that :(
  int _itemCount = 0;

  int get bufferLength => _itemCount;

  MicData get view => _buffer.sublist(0);

  /// Submits a new chunk of data to the buffer. The existing data will be shifted to the front of the buffer and the new data will be added to the end.
  void submit(MicData list) {
    _updateBuffer(list);
    if (_itemCount == fftSize) {
      // we have enough data to run the fft
      _runFft();
    }
  }

  void _updateBuffer(Float32List list) {
    if (list.length >= fftSize) {
      // calculate where to start in the list
      var skipCount = list.length - fftSize;

      _buffer.setRange(0, fftSize, list, skipCount);
      _itemCount = fftSize;
    } else if (_itemCount + list.length <= fftSize) {
      // if the buffer is not yet filled, and the new list fits into the buffer, simply add the new list to the end
      _buffer.setRange(_itemCount, _itemCount + list.length, list);
      _itemCount += list.length;
    } else {
      var shiftBy = (list.length + _itemCount) - fftSize;

      _buffer.setRange(0, _itemCount - shiftBy, _buffer, shiftBy);
      _buffer.setRange(_itemCount - shiftBy, _itemCount + list.length - shiftBy, list);

      _itemCount = fftSize;
    }
  }

  void _runFft() {
    // logger.i('Running FFT on buffer size of ${_buffer.length}');
    assert(_buffer.length == fftSize, 'Buffer length is not equal to fftSize');
    var complexData = _fft.realFft(_buffer);

    var spectrum = complexData.sublist(0, maxBucketIndex + 1).magnitudes();

    int peakIdx = -1;
    double max = -1;
    spectrum.forEachIndexed((index, element) {
      if (!element.isNaN && (peakIdx == -1 || element > max)) {
        peakIdx = index;
        max = element;
      }
    });

    if (peakIdx > 0) {
      var peakFreq = _fft.frequency(peakIdx, _sampleRate);
      // logger.i('Peak: ${peakFreq.toStringAsFixed(1)}Hz : ${max.toStringAsFixed(2)}');
      _peakFrequencyController.add(peakFreq.round());
    }
  }

  void dispose() {
    _peakFrequencyController.close();
  }
}
