
class Folder {
  static int modifiedComparator(folderA, folderB) => folderB.modified.compareTo(folderA.modified);
  static int nameComparator(folderA, folderB) => folderA.name.compareTo(folderB.name);


  Folder({required this.name, required this.modified, required this.size});

  final double modified;

  final String name;

  final int size;


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Folder &&
          runtimeType == other.runtimeType &&
          modified == other.modified &&
          name == other.name &&
          size == other.size;

  @override
  int get hashCode => modified.hashCode ^ name.hashCode ^ size.hashCode;
}
