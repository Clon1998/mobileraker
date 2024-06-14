/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:easy_localization/easy_localization.dart';

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

  Uri? constructSmallImageUri(Uri? baseUri) {
    if (baseUri == null || smallImagePath == null) return null;
    return baseUri.replace(pathSegments: [
      ...baseUri.pathSegments,
      'server',
      'files',
      ...parentPath.split('/'),
      ...smallImagePath!.split('/')
    ]);
  }

  String get slicerAndVersion {
    String ukwn = tr('general.unknown');
    if (slicerVersion == null) return slicer ?? ukwn;

    return '${slicer ?? ukwn} (v$slicerVersion)';
  }

  String formatPotentialEta(DateFormat dateFormat) {
    if (estimatedTime == null) return tr('general.unknown');
    var eta = DateTime.now().add(Duration(seconds: estimatedTime!.toInt())).toLocal();
    return dateFormat.format(eta);
  }
}
