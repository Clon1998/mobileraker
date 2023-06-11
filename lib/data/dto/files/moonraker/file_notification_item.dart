/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

class FileNotificationItem {
  final String path;
  final String root;
  final int? size;
  final double? modified;

  String get fullPath => '$root/$path';

  FileNotificationItem.fromJson(Map<String, dynamic> json)
      : path = json['path'],
        root = json['root'],
        size = json['size'],
        modified = double.tryParse(json['modified'].toString());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileNotificationItem &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          root == other.root;

  @override
  int get hashCode => path.hashCode ^ root.hashCode;

  @override
  String toString() {
    return 'FileNotificationItem{path: $path, root: $root, size: $size, modified: $modified}';
  }
}
