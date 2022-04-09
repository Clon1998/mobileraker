class StampedEntity {
  StampedEntity(this.created, this.lastModified);

  final DateTime created;
  DateTime lastModified;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StampedEntity &&
          runtimeType == other.runtimeType &&
          created == other.created &&
          lastModified == other.lastModified;

  @override
  int get hashCode => created.hashCode ^ lastModified.hashCode;


}
