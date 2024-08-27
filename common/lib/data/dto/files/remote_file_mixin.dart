/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/object_extension.dart';

import '../../../service/moonraker/file_service.dart';

mixin RemoteFile {
  static int nameComparator(RemoteFile a, RemoteFile b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());

  static int modifiedComparator(RemoteFile a, RemoteFile b) => a.modified.compareTo(b.modified);

  static int sizeComparator(RemoteFile a, RemoteFile b) => a.size.compareTo(b.size);

  String get name;

  String get parentPath;

  double get modified;

  int get size;

  String get absolutPath => '$parentPath/$name';

  String get relativeToRoot => absolutPath.split('/').skip(1).join('/');

  String get fileName => name.split('.').let((it) => it.length > 1 ? it.sublist(0, it.length - 1).join('.') : name);

  String? get fileExtension => name.split('.').length > 1 ? name.split('.').last : null;

  // Check if the fileExtension is a video file of common video formats
  bool get isVideo => fileExtension != null && videoFileExtensions.contains(fileExtension);

  bool get isImage => fileExtension != null && imageFileExtensions.contains(fileExtension);

  bool get isArchive => fileExtension != null && archiveFileExtensions.contains(fileExtension);

  DateTime? get modifiedDate {
    if (modified <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(modified.toInt() * 1000);
  }
}
