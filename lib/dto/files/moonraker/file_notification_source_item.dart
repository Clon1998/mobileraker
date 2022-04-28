class FileNotificationSourceItem {
  final String path;
  final String root;

  FileNotificationSourceItem.fromJson(Map<String, dynamic> json)
      : this.path = json['path'],
        this.root = json['root'];

  String get fullPath => '$root/$path';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileNotificationSourceItem &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          root == other.root;

  @override
  int get hashCode => path.hashCode ^ root.hashCode;

  @override
  String toString() {
    return 'FileListChangedSourceItem{path: $path, root: $root}';
  }
}
