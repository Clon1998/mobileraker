/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

extension MobilerakerDateTime on DateTime {
  bool isToday() {
    final now = DateTime.now();
    return now.day == day && now.month == month && now.year == year;
  }

  bool isNotToday() => !isToday();
}
