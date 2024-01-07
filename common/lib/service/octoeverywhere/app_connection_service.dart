/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/octoeverywhere/app_connection_info_response.dart';
import 'package:common/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:common/exceptions/octo_everywhere_exception.dart';
import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../network/dio_provider.dart';

part 'app_connection_service.g.dart';

@riverpod
AppConnectionService appConnectionService(AppConnectionServiceRef ref) {
  return AppConnectionService(ref);
}

class AppConnectionService {
  AppConnectionService(AutoDisposeRef ref) : _dio = ref.watch(octoApiClientProvider);

  final Dio _dio;

  final Uri _octoURI = Uri(
    scheme: 'https',
    host: 'octoeverywhere.com',
  );

  Future<AppPortalResult> linkAppWithOcto({String? printerId}) async {
    var uri = _octoURI.replace(path: 'appportal/v1/', queryParameters: {
      'appid': 'mobileraker',
      'moonraker': 'true',
      'returnUrl': 'mobileraker://octoeverywhere',
      'appLogoUrl': 'https://raw.githubusercontent.com/Clon1998/mobileraker/master/assets/icon/mr_appicon.png',
      if (printerId != null) 'printerId': printerId,
    });

    try {
      final result = await FlutterWebAuth.authenticate(url: uri.toString(), callbackUrlScheme: 'mobileraker');

      var resultParameters = Uri.parse(result).queryParameters;

      if (resultParameters['success'] != 'true') {
        throw const OctoEverywhereException(
          'octoeverywhere.com returned unsuccessful linking result',
        );
      }

      return AppPortalResult.fromJson(resultParameters);
    } on PlatformException catch (e) {
      logger.e('Error during Octo Setup', e);
      throw const OctoEverywhereException('Setup process canceled!');
    }
  }

  Future<AppConnectionInfoResponse> getInfo(String appToken) async {
    var response = await _dio.get('/appconnection/info', options: Options(headers: {'AppToken': appToken}));

    logger.i('OctoInfoAPI: Result code: ${response.statusCode}');
    return AppConnectionInfoResponse.fromJson(response.data);
  }
}
