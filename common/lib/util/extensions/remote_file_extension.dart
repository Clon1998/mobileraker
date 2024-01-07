/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import '../../data/dto/files/remote_file_mixin.dart';

extension UriRemoteFileExtension on RemoteFile {
  Uri? downloadUri(Uri? baseUri) {
    if (baseUri == null) return null;
    return baseUri.replace(pathSegments: [...baseUri.pathSegments, 'server', 'files', ...parentPath.split('/'), name]);
  }
}
