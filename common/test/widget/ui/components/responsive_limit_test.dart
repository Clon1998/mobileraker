/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/components/responsive_limit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  const content = SizedBox(key: Key('content'), height: 10, width: double.infinity);

  double contentWidth(WidgetTester tester) => tester.getSize(find.byKey(const Key('content'))).width;

  testWidgets('uses the full width on a phone', (tester) async {
    await tester.pumpApp(const ResponsiveLimit(child: content), device: TestDevice.phone);

    expect(contentWidth(tester), TestDevice.phone.size.width);
  });

  testWidgets('limits the width to the end of the medium breakpoint on a tablet', (tester) async {
    await tester.pumpApp(const Center(child: ResponsiveLimit(child: content)), device: TestDevice.tablet);

    expect(contentWidth(tester), 840);
  });
}
