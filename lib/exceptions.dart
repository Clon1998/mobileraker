/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:mobileraker/data/data_source/json_rpc_client.dart';

class MobilerakerException implements Exception {
  final String message;
  final Object? parentException;
  final StackTrace? parentStack;

  const MobilerakerException(this.message,
      {this.parentException, this.parentStack});

  @override
  String toString() {
    return 'MobilerakerException{$message, parentException: $parentException, parentStack: $parentStack}';
  }
}

class FileFetchException extends MobilerakerException {
  final String? reqPath;

  const FileFetchException(String message, {this.reqPath}) : super(message);

  @override
  String toString() {
    return 'FileFetchException{path: $reqPath, error: $message}';
  }
}

class OctoEverywhereException extends MobilerakerException {
  const OctoEverywhereException(String message,
      {super.parentException, super.parentStack})
      : super(message);


  @override
  String toString() {
    return 'OctoEverywhereException{$message, parentException: $parentException, parentStack: $parentStack}';
  }
}

class OctoEverywhereHttpException extends OctoEverywhereException {
  const OctoEverywhereHttpException(String message, this.statusCode,
      {super.parentException, super.parentStack})
      : super(message);

  final int statusCode;

  @override
  String toString() {
    return 'OctoEverywhereHttpException{$message, $statusCode, parentException: $parentException, parentStack: $parentStack}';
  }
}

/// Thrown whenever a Gcode exception fails!
class GCodeException extends MobilerakerException {
  const GCodeException(super.message, this.code, this.error,
      {super.parentException, super.parentStack});

  factory GCodeException.fromJrpcError(JRpcError e, {StackTrace? parentStack}) {
    Map<String, dynamic> errorInfo =
        jsonDecode(e.message.replaceAll('\'', '"'));

    return GCodeException(
        errorInfo['message'] ?? 'UNKNOWN', e.code, errorInfo['error'],
        parentException: e);
  }

  final int code;
  final String error;

  @override
  String toString() {
    return 'GCodeException{code: $code, message: $message, error:$error, parentException: $parentException, parentStack: $parentStack}';
  }
}
