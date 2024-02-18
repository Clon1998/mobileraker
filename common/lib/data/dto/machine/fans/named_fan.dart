/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'fan.dart';

abstract class NamedFan implements Fan {
  const NamedFan();
  abstract final String name;

  String get configName => name.toLowerCase();
}
