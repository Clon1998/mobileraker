/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:mobileraker/data/dto/files/gcode_file.dart';

extension UriExtension on GCodeFile {
  /// Constructs the Uri of the BigImage, if it is available!
  ///
  Uri? constructBigImageUri(Uri? baseUri) {
    if (baseUri == null || bigImagePath == null) return null;
    return baseUri.replace(pathSegments: [
      ...baseUri.pathSegments,
      'server',
      'files',
      ...parentPath.split('/'),
      ...bigImagePath!.split('/')
    ]);
  }
}
