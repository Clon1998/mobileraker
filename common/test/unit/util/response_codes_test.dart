/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/exceptions/obico_exception.dart';
import 'package:common/exceptions/octo_everywhere_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/misc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('verifyHttpResponseCodesForObico', () {
    test('401 throws an Obico exception', () {
      expect(() => verifyHttpResponseCodesForObico(401), throwsA(isA<ObicoHttpException>()));
    });

    test('200 does not throw', () => verifyHttpResponseCodesForObico(200));

    test('481 throws an Obico exception', () {
      expect(() => verifyHttpResponseCodesForObico(481), throwsA(isA<ObicoHttpException>()));
    });
  });

  group('OctoEverywhere messages', () {
    test('400 message has no typo', () {
      expect(
        () => verifyHttpResponseCodes(400, ClientType.octo),
        throwsA(isA<OctoEverywhereHttpException>().having((e) => e.message, 'message', isNot(contains('too fetch')))),
      );
    });
  });

  group('verifyHttpResponseCodes', () {
    test('599 message has no stray text', () {
      expect(
        () => verifyHttpResponseCodes(599),
        throwsA(isA<HttpException>().having((e) => e.message, 'message', isNot(contains('override')))),
      );
    });
  });

  group('convertDioException for OctoEverywhere', () {
    DioException badResponse(int statusCode) {
      final options = RequestOptions(path: '/', extra: {'mrClientType': ClientType.octo});
      return DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: statusCode),
      );
    }

    test('401 keeps its status code', () {
      final err = convertDioException(badResponse(401));
      expect(err, isA<OctoEverywhereDioException>());
      expect(err.message, endsWith('- 401'));
    });

    test('400 keeps its status code', () {
      expect(convertDioException(badResponse(400)).message, endsWith('- 400'));
    });
  });
}
