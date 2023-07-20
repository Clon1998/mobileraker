/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

mixin RemoteFile {
  static int nameComparator(RemoteFile a, RemoteFile b) =>
      a.name.compareTo(b.name);

  static int modifiedComparator(RemoteFile a, RemoteFile b) =>
      b.modified.compareTo(a.modified);

  String get name;

  String get parentPath;

  double get modified;

  int get size;

  String get absolutPath => '$parentPath/$name';

  DateTime get modifiedDate {
    return DateTime.fromMillisecondsSinceEpoch(modified.toInt() * 1000);
  }
}
