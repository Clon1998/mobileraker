/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/util/logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Returns the ObjectsJson from the moonraker JSON result using
/// /printer/objects/query?<OBJECT> Endpoint
Map<String, dynamic> objectFromHttpApiResult(String input, String objectKey) {
  var rawJson = jsonDecode(input);
  return rawJson['result']['status'][objectKey];
}

void setupTestLogger() {
  talker = Talker(
    settings: TalkerSettings(),
    logger: TalkerLogger(
      settings: TalkerLoggerSettings(
        // Set current logging level
        level: LogLevel.info,
      ),
    ),
  );
}
