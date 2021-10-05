class GCodeThumbnail {
  late int width;
  late int height;
  late int size;
  late String relativePath;

  GCodeThumbnail(
      {required this.width,
        required this.height,
        required this.size,
        required this.relativePath});

  GCodeThumbnail.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('width')) this.width = json['width'];
    if (json.containsKey('height')) this.height = json['height'];
    if (json.containsKey('size')) this.size = json['size'];
    if (json.containsKey('relative_path'))
      this.relativePath = json['relative_path'];
  }
}