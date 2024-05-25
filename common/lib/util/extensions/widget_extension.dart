/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

extension MobilerakerDebugWidget on Widget {
  // Helper to easy see bounding boxes
  Widget colored(Color? color) {
    if (!kDebugMode) return this;
    return Container(
      color: color,
      child: this,
    );
  }
}
