/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

extension MobilerakerDateTime on DateTime {
  int get secondsSinceEpoch => millisecondsSinceEpoch ~/ 1000;
}
