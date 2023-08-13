/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

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
}
