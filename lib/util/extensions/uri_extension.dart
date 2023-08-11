/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

extension MobilerakerUri on Uri {
  String skipScheme() => (hasScheme)
      ? toString().replaceRange(0, scheme.length - 1, '')
      : toString();

  Uri appendPath(String path) => replace(
      pathSegments: pathSegments +
          path.split('/').where((element) => element.isNotEmpty).toList());
}
