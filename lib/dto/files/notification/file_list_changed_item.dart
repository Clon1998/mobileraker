class FileListChangedItem {
  late String path;
  late String root;
  late int size;
  late double modified;

  FileListChangedItem(this.path, this.root, this.size, this.modified);

  FileListChangedItem.fromJson(Map<String, dynamic> json) {
    path = json['path'];
    root = json['root'];
    size = json['size'];
    modified = double.tryParse(json['modified'].toString()) ?? 0;
  }

  String get fullPath => '$root/$path';

  @override
  String toString() {
    return 'FileListChangedItem{path: $path, root: $root, size: $size, modified: $modified}';
  }
}
