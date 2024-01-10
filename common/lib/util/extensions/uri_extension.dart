/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/util/extensions/string_extension.dart';

extension MobilerakerUri on Uri {
  String skipScheme() => (hasScheme) ? toString().replaceRange(0, scheme.length - 1, '') : toString();

  Uri appendPath(String path) =>
      replace(pathSegments: pathSegments + path.split('/').where((element) => element.isNotEmpty).toList());

  Uri removePort() => replace(
          port: switch (scheme) {
        'http' => 80,
        'https' => 443,
        _ => 0,
      });

  Uri removeUserInfo() => replace(userInfo: '');

  Uri toWebsocketUri() {
    return replace(
        scheme: switch (scheme) {
          'http' || 'ws' => 'ws',
          'https' || 'wss' => 'wss',
          _ => 'ws',
        },
        port: switch (port) {
          80 || 443 => 0,
          _ => port,
        });
  }

  Uri toHttpUri() {
    return replace(
        scheme: switch (scheme) {
          'http' || 'ws' => 'http',
          'https' || 'wss' => 'https',
          _ => 'http',
        },
        port: switch (port) {
          0 => switch (scheme) {
              'http' || 'ws' => 80,
              'https' || 'wss' => 443,
              _ => 0,
            },
          _ => port,
        });
  }

  /// Hide the userInfo to ensure we can safely log the uri
  Uri obfuscate() => replace(userInfo: userInfo.obfuscate());

  String? get basicAuth {
    if (userInfo.isNotEmpty) {
      String auth = base64Encode(utf8.encode(userInfo));
      return 'Basic $auth';
    }
    return null;
  }
}
