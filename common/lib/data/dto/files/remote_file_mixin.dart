/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

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

  String get fileName => name.split('.').first;

  String? get fileExtension => name.split('.').length > 1 ? name.split('.').last : null;

  // Check if the fileExtension is a video file of common video formats
  bool get isVideo => fileExtension != null && ['mp4'].contains(fileExtension);

  bool get isImage => fileExtension != null && ['jpg', 'jpeg', 'png'].contains(fileExtension);

  DateTime? get modifiedDate {
    if (modified <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(modified.toInt() * 1000);
  }
}
