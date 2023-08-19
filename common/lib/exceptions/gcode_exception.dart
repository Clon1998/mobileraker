/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import '../network/json_rpc_client.dart';
import 'mobileraker_exception.dart';

/// Thrown whenever a Gcode exception fails!
class GCodeException extends MobilerakerException {
  const GCodeException(super.message, this.code, this.error,
      {super.parentException, super.parentStack});

  factory GCodeException.fromJrpcError(JRpcError e, {StackTrace? parentStack}) {
    Map<String, dynamic> errorInfo = jsonDecode(e.message.replaceAll('\'', '"'));

    return GCodeException(errorInfo['message'] ?? 'UNKNOWN', e.code, errorInfo['error'],
        parentException: e);
  }

  final int code;
  final String error;

  @override
  String toString() {
    return 'GCodeException{code: $code, message: $message, error:$error, parentException: $parentException, parentStack: $parentStack}';
  }
}
