/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:hive/hive.dart';

part 'webcam_rotation.g.dart';

@HiveType(typeId: 9)
enum WebCamRotation {
  @HiveField(0)
  landscape,
  @HiveField(1)
  portrait }
