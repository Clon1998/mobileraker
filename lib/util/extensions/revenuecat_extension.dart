/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

extension MobilerakerDiscount on StoreProductDiscount {
  String get discountDurationText {
    //DAY, WEEK, MONTH or YEAR.
    var dateUnit = switch (periodUnit) {
      'YEAR' => plural('date.year', cycles),
      'MONTH' => plural('date.month', cycles),
      'WEEK' => plural('date.week', cycles),
      'DAY' => plural('date.day', cycles),
      _ => throw ArgumentError('Detected unsupported period')
    };

    return '$cycles $dateUnit';
  }
}
