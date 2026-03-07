/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/single_or_list_converter.dart';

class DoubleListConverter extends SingleOrListConverter<double> {
  const DoubleListConverter() : super(_parse);

  static double _parse(Object? v) {
    if (v is num) {
      return v.toDouble();
    }
    return double.parse(v as String);
  }
}
