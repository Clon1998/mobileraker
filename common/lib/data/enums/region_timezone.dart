/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

enum RegionTimezone {
  usWest('us_west', (-12, -6)),
  usEast('us_east', (-5, -3)),
  europeAfrica('europe_africa', (-1, 3)),
  asiaSouth('asia_south', (4, 6)),
  asiaEast('asia_east', (7, 9)),
  oceania('oceania', (10, 14)),
  global('global', (-1, -1));

  final String name;

  final (int, int) utcOffsetRange;

  const RegionTimezone(this.name, this.utcOffsetRange);

  static RegionTimezone fromUtcOffset(int utcOffset) {
    for (var regionTimezone in RegionTimezone.values) {
      if (regionTimezone.utcOffsetRange.$1 <= utcOffset && regionTimezone.utcOffsetRange.$2 >= utcOffset) {
        return regionTimezone;
      }
    }

    return RegionTimezone.global;
  }
}
