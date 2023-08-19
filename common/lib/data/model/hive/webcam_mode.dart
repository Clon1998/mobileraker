/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:hive/hive.dart';

part 'webcam_mode.g.dart';

@HiveType(typeId: 6)
enum WebCamMode {
  @HiveField(0)
  STREAM,
  @HiveField(1)
  ADAPTIVE_STREAM
}
