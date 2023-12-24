/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/util/extensions/uri_extension.dart';

extension MachineLoggingExtension on Machine {
  String get logName => '$name ($uuid)';

  String get logNameExtended => '$logName@${wsUri.obfuscate()}';

  String get logTag => '[$logName]';

  String get logTagExtended => '[$logNameExtended]';
}
