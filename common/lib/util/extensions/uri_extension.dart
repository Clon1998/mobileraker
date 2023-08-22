/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/string_extension.dart';

extension MobilerakerUri on Uri {
  String skipScheme() =>
      (hasScheme) ? toString().replaceRange(0, scheme.length - 1, '') : toString();

  Uri appendPath(String path) => replace(
      pathSegments: pathSegments + path.split('/').where((element) => element.isNotEmpty).toList());

  Uri removePort() => replace(
          port: switch (scheme) {
        'http' => 80,
        'https' => 443,
        _ => 0,
      });

  Uri toWebsocketUri() {
    return replace(
        scheme: switch (scheme) {
          'http' => 'ws',
          'https' => 'wss',
          _ => scheme,
        },
        port: switch (port) {
          80 || 443 => 0,
          _ => port,
        });
  }

  /// Hide the userInfo to ensure we can safely log the uri
  Uri obfuscate() => replace(userInfo: userInfo.obfuscate());
}
