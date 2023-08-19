/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/util/logger.dart';
import 'package:logger/logger.dart';

/// Returns the ObjectsJson from the moonraker JSON result using
/// /printer/objects/query?<OBJECT> Endpoint
Map<String, dynamic> objectFromHttpApiResult(String input, String objectKey) {
  var rawJson = jsonDecode(input);
  return rawJson['result']['status'][objectKey];
}

void setupTestLogger() {
  Logger.level = Level.info;
  logger = Logger(
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 500, noBoxingByDefault: true),
    output: ConsoleOutput(),
  );
}
