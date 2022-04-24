class File {
  File(this.name, this.modified, this.size, this.parentPath);

  File.fromJson(Map<String, dynamic> json, this.parentPath)
      : name = json['filename'],
        size = json['size'],
        modified = json['modified'];

  /// MOONRAKER FIELDS:
  String name;

  double modified;

  int size;

  /// Path to the location/directory where the file is located
  String parentPath;

  DateTime? get modifiedDate {
    return DateTime.fromMillisecondsSinceEpoch(modified.toInt() * 1000);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is File &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          modified == other.modified &&
          size == other.size &&
          parentPath == other.parentPath;

  @override
  int get hashCode =>
      name.hashCode ^ modified.hashCode ^ size.hashCode ^ parentPath.hashCode;
}
