/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/region_timezone.dart';

extension MobilerakerDateTime on DateTime {
  int get secondsSinceEpoch => millisecondsSinceEpoch ~/ 1000;

  RegionTimezone get regionTimezone => RegionTimezone.fromUtcOffset(timeZoneOffset.inHours);
}
