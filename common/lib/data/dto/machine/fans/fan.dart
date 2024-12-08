/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import '../../config/config_file_object_identifiers_enum.dart';

abstract class Fan {
  abstract final double speed;
  abstract final double? rpm;

  ConfigFileObjectIdentifiers get kind;
}
