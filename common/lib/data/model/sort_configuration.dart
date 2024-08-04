/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import '../dto/files/gcode_file.dart';
import '../dto/files/remote_file_mixin.dart';
import '../enums/sort_kind_enum.dart';
import '../enums/sort_mode_enum.dart';

/// Encapsulates the active sort mode and its direction.
class SortConfiguration {
  const SortConfiguration(this.mode, this.kind);

  SortConfiguration.withDefaultKind(SortMode mode) : this(mode, mode.defaultKind);

  final SortMode mode;
  final SortKind kind;

  Comparator<RemoteFile> get comparator {
    final comp = switch (mode) {
      SortMode.name when kind == SortKind.ascending => RemoteFile.nameComparator,
      SortMode.name when kind == SortKind.descending => (a, b) => RemoteFile.nameComparator(b, a),
      SortMode.lastPrinted when kind == SortKind.ascending => GCodeFile.lastPrintedComparator,
      SortMode.lastPrinted when kind == SortKind.descending => (a, b) => GCodeFile.lastPrintedComparator(b, a),
      SortMode.lastModified when kind == SortKind.ascending => RemoteFile.modifiedComparator,
      SortMode.lastModified when kind == SortKind.descending => (a, b) => RemoteFile.modifiedComparator(b, a),
      SortMode.size when kind == SortKind.ascending => RemoteFile.sizeComparator,
      SortMode.size when kind == SortKind.descending => (a, b) => RemoteFile.sizeComparator(b, a),
      _ => throw UnimplementedError('Unknown sort mode: $mode'),
    };
    return comp;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortConfiguration &&
          runtimeType == other.runtimeType &&
          (identical(mode, other.mode) || mode == other.mode) &&
          (identical(kind, other.kind) || kind == other.kind);

  @override
  int get hashCode => Object.hash(mode, kind);

  @override
  String toString() => 'SortConfiguration(mode: $mode, kind: $kind)';
}
