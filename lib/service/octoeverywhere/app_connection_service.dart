/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_connection_info_response.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_connection_service.g.dart';

@Riverpod()
AppConnectionService appConnectionService(AppConnectionServiceRef ref) {
  return AppConnectionService(ref);
}

class AppConnectionService {
  AppConnectionService(AutoDisposeRef ref) {
    // ref.onDispose(() { });
  }

  final Uri _octoURI = Uri(
    scheme: 'https',
    host: 'octoeverywhere.com',
  );

  Future<AppPortalResult> linkAppWithOcto({String? printerId}) async {
    var uri = _octoURI.replace(path: 'appportal/v1/', queryParameters: {
      'appid': 'mobileraker',
      'moonraker': 'true',
      'returnUrl': 'octoeverywhere://mobileraker',
      'appLogoUrl':
          'https://raw.githubusercontent.com/Clon1998/mobileraker/master/assets/icon/mr_appicon.png',
      if (printerId != null) 'printerId': printerId,
    });

    try {
      final result = await FlutterWebAuth.authenticate(
          url: uri.toString(), callbackUrlScheme: 'octoeverywhere');

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
    var actualUri = _octoURI.replace(path: 'api/appconnection/info');

    http.Response response =
        await http.get(actualUri, headers: {'AppToken': appToken});

    logger.i('OctoInfoAPI: Result code: ${response.statusCode}');
    verifyHttpResponseCodes(response.statusCode, ClientType.octo);
    return AppConnectionInfoResponse.fromJson(jsonDecode(response.body));
  }
}
