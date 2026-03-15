/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../util/misc.dart';
import '../../../dto/config/config_file_object_identifiers_enum.dart';

part 'reordable_element.freezed.dart';
part 'reordable_element.g.dart';

@freezed
sealed class ReordableElement with _$ReordableElement {
  ReordableElement._({String? uuid}): uuid = uuid ?? Uuid().v4();

  factory ReordableElement({
    String? uuid,
    required String name,
    required ConfigFileObjectIdentifiers kind,
  }) = _ReordableElement;

  factory ReordableElement.fromJson(Map<String, dynamic> json) => _$ReordableElementFromJson(json);

  @override
  final String uuid;

  String get beautifiedName => beautifyName(name);
}
