/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:duo_kit/testing.dart';
import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Window metrics of a device for widget tests, in logical pixels.
///
/// The test view uses a device pixel ratio of 1, so logical and physical pixels are the same.
///
/// The iPhone Duo devices only report their strip on iOS (that is how duo_kit detects it). Run those tests with
/// `variant: TargetPlatformVariant.only(TargetPlatform.iOS)`; [TestDevice.apply] fails with a hint otherwise.
class TestDevice {
  const TestDevice(
    this.name, {
    required this.size,
    this.padding = EdgeInsets.zero,
    this.displayFeatures = const [],
    this.requiresIOS = false,
  });

  /// Window metrics of an iPhone Duo pose, measured on the simulator (see duo_kit's [FoldTestPose]).
  TestDevice.duo(FoldTestPose pose)
    : this(
        pose.name,
        size: pose.data.size,
        padding: pose.data.viewPadding,
        displayFeatures: pose.data.displayFeatures,
        requiresIOS: true,
      );

  /// A plain window of the given size, e.g. to test both sides of a breakpoint.
  TestDevice.sized(double width, double height) : this('${width.toInt()}x${height.toInt()}', size: Size(width, height));

  /// Pixel 8a in portrait (compact).
  static const phone = TestDevice('phone', size: Size(411, 914), padding: EdgeInsets.only(top: 24, bottom: 24));

  /// Pixel 8a in landscape (medium, by width).
  static const phoneLandscape = TestDevice('phoneLandscape', size: Size(914, 411), padding: EdgeInsets.only(left: 24));

  /// Pixel Tablet in landscape (expanded).
  static const tablet = TestDevice('tablet', size: Size(1280, 800), padding: EdgeInsets.only(top: 24, bottom: 24));

  /// Pixel Tablet in portrait (medium).
  static const tabletPortrait = TestDevice(
    'tabletPortrait',
    size: Size(800, 1280),
    padding: EdgeInsets.only(top: 24, bottom: 24),
  );

  /// iPhone Duo inner display in landscape, lying flat: strip on the right.
  static final duoInnerLandscape = TestDevice.duo(FoldTestPose.duoInnerLandscape);

  /// iPhone Duo inner display in portrait, lying flat: no strip.
  static final duoInnerPortrait = TestDevice.duo(FoldTestPose.duoInnerPortrait);

  /// iPhone Duo cover display (closed) with its camera and status cluster: strip on the right.
  static final duoCover = TestDevice.duo(FoldTestPose.duoCoverWithOcclusions);

  final String name;
  final Size size;
  final EdgeInsets padding;
  final List<DisplayFeature> displayFeatures;
  final bool requiresIOS;

  /// Applies the metrics to the test view. They are reset when the test ends.
  void apply(WidgetTester tester) {
    assert(
      !requiresIOS || defaultTargetPlatform == TargetPlatform.iOS,
      'TestDevice "$name" only reports its strip on iOS. '
      'Add `variant: TargetPlatformVariant.only(TargetPlatform.iOS)` to the testWidgets call.',
    );
    final view = tester.view;
    view.devicePixelRatio = 1;
    view.physicalSize = size;
    final fakePadding = FakeViewPadding(
      left: padding.left,
      top: padding.top,
      right: padding.right,
      bottom: padding.bottom,
    );
    view.padding = fakePadding;
    view.viewPadding = fakePadding;
    view.displayFeatures = displayFeatures;
    addTearDown(view.reset);
  }

  @override
  String toString() => 'TestDevice($name)';
}
