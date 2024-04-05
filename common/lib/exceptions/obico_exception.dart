/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:dio/dio.dart';

import 'mobileraker_exception.dart';

class ObicoException extends MobilerakerException {
  const ObicoException(super.message, {super.parentException, super.parentStack});

  @override
  String toString() {
    return 'ObicoException{$message, parentException: $parentException, parentStack: $parentStack}';
  }
}

class ObicoHttpException extends ObicoException {
  const ObicoHttpException(super.message, this.statusCode, {super.parentException, super.parentStack});

  final int statusCode;

  @override
  String toString() {
    return 'ObicoHttpException{$message, $statusCode, parentException: $parentException, parentStack: $parentStack}';
  }
}

class ObicoDioException extends MobilerakerDioException implements ObicoException {
  ObicoDioException(
    String message,
    int statusCode, {
    required super.requestOptions,
  }) : super(type: DioExceptionType.badResponse, message: '$message - $statusCode');

  @override
  String toString() {
    return 'ObicoDioException [Bad Response]: $message';
  }
}