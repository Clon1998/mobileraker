import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mobileraker/data/dto/octoeverywhere/app_connection_info_response.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/util/misc.dart';

final appConnectionServiceProvider =
    Provider.autoDispose<AppConnectionService>((ref) {
  ref.keepAlive();

  return AppConnectionService(ref);
});

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
    verifyResponseCode(response.statusCode);
    return AppConnectionInfoResponse.fromJson(jsonDecode(response.body));
  }

  static verifyResponseCode(int statusCode) {
    switch (statusCode) {
      case 200:
        return;
      case 400:
        throw const OctoEverywhereException(
            'Internal App error while trying too fetch info. No AppToken was found!');
      case 600:
        throw const OctoEverywhereException(
            'Unknown Error - Something went wrong, try again later.');
      case 601:
        throw const OctoEverywhereException(
            'Printer is Not Connected To OctoEverywhere');
      case 602:
        throw const OctoEverywhereException(
            'OctoEverywhere\'s Connection to Klipper Timed Out.');
      case 603:
        throw const OctoEverywhereException('App Connection Not Found');
      case 604:
        throw const OctoEverywhereException('App Connection Revoked/Expired');
      case 605:
        throw const OctoEverywhereException(
            'App Connection Owner\'s Account Is No Longer a Supporter.');
      case 606:
        throw const OctoEverywhereException(
            'Invalid App Connection Credentials');
      case 607:
        throw const OctoEverywhereException('File Download Limit Exceeded');
      case 608:
        throw const OctoEverywhereException('File Upload Limit Exceeded');
      case 609:
        throw const OctoEverywhereException(
            'Webcam Back to Back Limit Exceeded');
      default:
        throw MobilerakerException(
            'Unknown Error - Response from octoeverywhere could not be parsed');
    }
  }
}
