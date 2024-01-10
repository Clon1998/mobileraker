/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

mixin RemoteFile {
  static int nameComparator(RemoteFile a, RemoteFile b) => a.name.compareTo(b.name);

  static int modifiedComparator(RemoteFile a, RemoteFile b) => b.modified.compareTo(a.modified);

  String get name;

  String get parentPath;

  double get modified;

  int get size;

  String get absolutPath => '$parentPath/$name';

  String get fileName => name.split('.').first;

  String? get fileExtension => name.split('.').length > 1 ? name.split('.').last : null;

  // Check if the fileExtension is a video file of common video formats
  bool get isVideo => fileExtension != null && ['mp4'].contains(fileExtension);

  bool get isImage => fileExtension != null && ['jpg', 'jpeg', 'png'].contains(fileExtension);

  DateTime get modifiedDate {
    return DateTime.fromMillisecondsSinceEpoch(modified.toInt() * 1000);
  }
}
