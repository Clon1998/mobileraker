/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/data/dto/obico/platform_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../exceptions/obico_exception.dart';
import '../../network/dio_provider.dart';
import '../../util/logger.dart';

part 'obico_tunnel_service.g.dart';

@riverpod
ObicoTunnelService obicoTunnelService(ObicoTunnelServiceRef ref, [Uri? uri]) {
  uri ??= Uri(
    scheme: 'https',
    host: 'app.obico.io',
  );

  return ObicoTunnelService(ref, uri);
}

class ObicoTunnelService {
  ObicoTunnelService(AutoDisposeRef ref, Uri uri)
      : _obicoUri = uri,
        _dio = ref.read(obicoApiClientProvider(uri.toString()));

  final Dio _dio;

  final Uri _obicoUri;

  Future<Uri> linkApp({String? printerId}) async {
    var uri = _obicoUri.replace(path: 'tunnels/new', queryParameters: {
      'app': 'mobileraker-${Platform.operatingSystem}',
      'success_redirect_url': 'mobileraker://obico',
      'platform': 'Klipper',
      if (printerId != null) 'printerId': printerId,
    });

    try {
      final result = await FlutterWebAuth.authenticate(url: uri.toString(), callbackUrlScheme: 'mobileraker');

      var resultParameters = Uri.parse(result).queryParameters;
      logger.i('Obico Linking Result: $resultParameters');

      return _parseAndValidateTunnelUri(resultParameters);
    } on PlatformException catch (e) {
      logger.e('Error during Obico Setup', e);
      throw const ObicoException('Linking process cancelled');
    }
  }

  /// TODO: This could actually be moved into a seperate service. Since it requires always the tunnel to be valid.
  /// Retrieves the platform info from the obico tunnel endpoint.
  /// The Endpoint is the Uri returned from the linkApp method, which also includes the authentication information.
  Future<PlatformInfo> retrievePlatformInfo(Uri tunnelUri) async {
    var uri = tunnelUri.resolve('_tsd_/dest_platform_info/');

    var response = await _dio.getUri(uri);

    logger.i('Received platform info from obico tunnel: ${response.data}');
    try {
      return PlatformInfo.fromJson(response.data);
    } catch (e, s) {
      logger.i('Error while parsing PlatformInfo response from obico tunnel: ${response.data}', e, s);
      throw const ObicoException('Error while parsing response from Obico');
    }
  }

  Uri _parseAndValidateTunnelUri(Map<String, String> queryParameters) {
    var endpoint = queryParameters['tunnel_endpoint'];
    if (endpoint == null) {
      logger.i('Obico linking failed, did not receive tunnel_endpoint');
      throw const ObicoException('Obico linking failed');
    }

    var tunnelUri = Uri.parse(endpoint);
    var userInfo = tunnelUri.userInfo.split(':');
    if (userInfo.length != 2) {
      logger.i('Obico linking failed, did not receive username and password. UserInfo length: ${userInfo.length}');
      throw const ObicoException('Obico linking failed');
    }
    return tunnelUri;
  }
}
