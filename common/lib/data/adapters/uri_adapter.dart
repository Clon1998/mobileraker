/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:hive_flutter/hive_flutter.dart';

class UriAdapter extends TypeAdapter<Uri> {
  @override
  final int typeId = 222;

  @override
  Uri read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Uri(
      scheme: fields[0] as String?,
      host: fields[1] as String?,
      port: fields[2] as int?,
      path: fields[3] as String?,
      query: fields[4] as String?,
      fragment: fields[5] as String?,
      userInfo: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Uri obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.scheme.isNotEmpty ? obj.scheme : null)
      ..writeByte(1)
      ..write(obj.host.isNotEmpty ? obj.host : null)
      ..writeByte(2)
      ..write(obj.hasPort ? obj.port : null)
      ..writeByte(3)
      ..write(obj.path.isNotEmpty ? obj.path : null)
      ..writeByte(4)
      ..write(obj.query.isNotEmpty ? obj.query : null)
      ..writeByte(5)
      ..write(obj.fragment.isNotEmpty ? obj.fragment : null)
      ..writeByte(6)
      ..write(obj.userInfo.isNotEmpty ? obj.userInfo : null);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UriAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
