/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/util/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/util/spectrum_analyzer.dart';

void main() {
  setUpAll(() {
    setupLogger();
  });

  test('Test basic buffer moving', () {
    SpectrumAnalyzer analyzer = SpectrumAnalyzer(32);
    expect(analyzer.bufferLength, 0);
    // Initial buffer is empty
    analyzer.submit(generateItems(10));
    expect(analyzer.bufferLength, 10);

    // Fill until buffer is full
    analyzer.submit(generateItems(22));
    expect(analyzer.bufferLength, 32);

    var a = generateItems(10);
    analyzer.submit(a);
    expect(analyzer.bufferLength, 32);
    var aView = analyzer.view;

    expect(aView.length, 32);
    expect(aView.sublist(22), equals(a));

    var b = generateItems(10);
    analyzer.submit(b);
    expect(analyzer.bufferLength, 32);
    var bView = analyzer.view;
    expect(bView.length, 32);
    expect(bView.sublist(22), equals(b));
    expect(bView.sublist(12, 22), equals(a));

    var c = generateItems(10);
    analyzer.submit(c);
    expect(analyzer.bufferLength, 32);
    var cView = analyzer.view;
    expect(cView.length, 32);
    expect(cView.sublist(22), equals(c));
    expect(cView.sublist(12, 22), equals(b));
    expect(cView.sublist(2, 12), equals(a));

    var d = generateItems(10);
    analyzer.submit(d);
    expect(analyzer.bufferLength, 32);
    var dView = analyzer.view;
    expect(dView.length, 32);
    expect(dView.sublist(22), equals(d));
    expect(dView.sublist(12, 22), equals(c));
    expect(dView.sublist(2, 12), equals(b));
    expect(dView.sublist(0, 2), equals(a.sublist(8, 10)));
  });

  test('Test submitting chunck bigger than buffer size', () {
    SpectrumAnalyzer analyzer = SpectrumAnalyzer(32);
    expect(analyzer.bufferLength, 0);
    // fill buffer
    var a = generateItems(40);
    analyzer.submit(a);
    expect(analyzer.bufferLength, 32);
    var aView = analyzer.view;
    expect(aView.length, 32);
    expect(aView, equals(a.sublist(8)));

    var b = generateItems(40);
    analyzer.submit(b);
    expect(analyzer.bufferLength, 32);
    var bView = analyzer.view;
    expect(bView.length, 32);
    expect(bView, equals(b.sublist(8)));

    var c = generateItems(10);
    analyzer.submit(c);
    expect(analyzer.bufferLength, 32);
    var cView = analyzer.view;
    expect(cView.length, 32);
    expect(cView.sublist(22), equals(c));
    expect(cView.sublist(0, 22), equals(b.sublist(18)));
  });

  test('Slowly filling the buffer', () {
    SpectrumAnalyzer analyzer = SpectrumAnalyzer(32);
    expect(analyzer.bufferLength, 0);
    for (int i = 0; i < 100; i++) {
      var e = generateItems(1);
      analyzer.submit(e);
      expect(analyzer.bufferLength, min(i + 1, 32));
      var eView = analyzer.view;
      expect(eView.length, 32);
      expect(eView[min(i, 31)], equals(e[0]));
    }
  });

  test('Test submitting with uneven chunks', () {
    SpectrumAnalyzer analyzer = SpectrumAnalyzer(64);
    expect(analyzer.bufferLength, 0);
    // fill buffer
    var a = generateItems(40);
    analyzer.submit(a);
    expect(analyzer.bufferLength, 40);
    var aView = analyzer.view;
    expect(analyzer.bufferLength, 40);
    expect(aView.sublist(0, 40), equals(a));

    var b = generateItems(15);
    analyzer.submit(b);
    expect(analyzer.bufferLength, 55);
    var bView = analyzer.view;
    expect(bView.sublist(40, 55), equals(b));
    expect(bView.sublist(0, 40), equals(a));

    var c = generateItems(6);
    analyzer.submit(c);
    expect(analyzer.bufferLength, 61);
    var cView = analyzer.view;
    expect(cView.sublist(55, 61), equals(c));
    expect(cView.sublist(40, 55), equals(b));
    expect(cView.sublist(0, 40), equals(a));

    var d = generateItems(2);
    analyzer.submit(d);
    expect(analyzer.bufferLength, 63);
    var dView = analyzer.view;
    expect(dView.sublist(61, 63), equals(d));
    expect(dView.sublist(55, 61), equals(c));
    expect(dView.sublist(40, 55), equals(b));
    expect(dView.sublist(0, 40), equals(a));

    var e = generateItems(2);
    analyzer.submit(e);
    expect(analyzer.bufferLength, 64);
    var eView = analyzer.view;

    expect(eView.sublist(62, 64), equals(e));
    expect(eView.sublist(60, 62), equals(d));
    expect(eView.sublist(54, 60), equals(c));
    expect(eView.sublist(39, 54), equals(b));
    expect(eView.sublist(0, 39), equals(a.sublist(1)));
  });
}

Float32List generateItems(int count) {
  Float32List items = Float32List(count);
  for (int i = 0; i < count; i++) {
    // generate random number between 0 and 1
    items[i] = Random().nextDouble();
  }
  return items;
}
