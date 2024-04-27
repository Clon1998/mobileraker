/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../util/misc.dart';
import '../../../dto/config/config_file_object_identifiers_enum.dart';

part 'reordable_element.freezed.dart';
part 'reordable_element.g.dart';

@freezed
class ReordableElement with _$ReordableElement {
  const ReordableElement._();

  const factory ReordableElement.__({
    required String uuid,
    required ConfigFileObjectIdentifiers kind,
    required String name,
    // @Default(true) bool visible,
  }) = _ReordableElement;

  factory ReordableElement({
    required String name,
    required ConfigFileObjectIdentifiers kind,
  }) {
    return ReordableElement.__(
      uuid: const Uuid().v4(),
      name: name,
      kind: kind,
    );
  }

  factory ReordableElement.fromJson(Map<String, dynamic> json) => _$ReordableElementFromJson(json);

  String get kindName => '${kind.name}::$name';

  String get beautifiedName => beautifyName(name);
}
