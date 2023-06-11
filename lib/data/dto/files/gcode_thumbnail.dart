/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

class GCodeThumbnail {
  final int width;
  final int height;
  final int size;
  final String relativePath;

  GCodeThumbnail(
      {required this.width,
      required this.height,
      required this.size,
      required this.relativePath});

  GCodeThumbnail.fromJson(Map<String, dynamic> json)
      : width = json['width'],
        height = json['height'],
        size = json['size'],
        relativePath = json['relative_path'];
}
