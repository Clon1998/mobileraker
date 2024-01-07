/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bottom_sheet_service_interface.g.dart';

mixin BottomSheetIdentifierMixin {}

@Riverpod(keepAlive: true)
BottomSheetService bottomSheetService(BottomSheetServiceRef ref) => throw UnimplementedError();

abstract interface class BottomSheetService {
  Map<BottomSheetIdentifierMixin, Widget Function(BuildContext, Object?)> get availableSheets;

  Future<BottomSheetResult> show(BottomSheetConfig config);
}

class BottomSheetConfig<T> {
  BottomSheetConfig({
    required this.type,
    this.isScrollControlled = false,
    this.data,
  });

  final BottomSheetIdentifierMixin type;
  final bool isScrollControlled;

  final T? data;
}

class BottomSheetResult<T> {
  BottomSheetResult({
    this.confirmed = false,
    this.data,
  });

  BottomSheetResult.confirmed([
    T? data,
  ]) : this(confirmed: true, data: data);

  BottomSheetResult.dismissed() : this(confirmed: false);

  /// Indicate if the bottom sheet was confirmed or dismissed
  final bool confirmed;

  // Optional data that can be passed back from the bottom sheet to the caller
  final T? data;

  @override
  String toString() {
    return 'BottomSheetResult{confirmed: $confirmed, data: $data}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BottomSheetResult &&
          runtimeType == other.runtimeType &&
          confirmed == other.confirmed &&
          data == other.data;

  @override
  int get hashCode => confirmed.hashCode ^ data.hashCode;
}
