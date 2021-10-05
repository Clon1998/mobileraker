class FileListChangedSourceItem {
  late String path;
  late String root;

  FileListChangedSourceItem(this.path, this.root);

  FileListChangedSourceItem.fromJson(Map<String, dynamic> json) {
    path = json['path'];
    root = json['root'];
  }

  String get fullPath => '$root/$path';

  @override
  String toString() {
    return 'FileListChangedSourceItem{path: $path, root: $root}';
  }
}
