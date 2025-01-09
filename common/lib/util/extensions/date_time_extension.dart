/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

extension MobilerakerDateTime on DateTime {
  int get secondsSinceEpoch => millisecondsSinceEpoch ~/ 1000;
}
