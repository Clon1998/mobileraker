/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bottom_sheet_service_interface.g.dart';

mixin BottomSheetIdentifierMixin {}

@Riverpod(keepAlive: true)
BottomSheetService bottomSheetService(BottomSheetServiceRef ref) => throw UnimplementedError();

abstract interface class BottomSheetService {
  Map<BottomSheetIdentifierMixin, Widget Function(BuildContext)> get availableSheets;

  show(BottomSheetConfig config);
}

class BottomSheetConfig {
  final BottomSheetIdentifierMixin type;

  BottomSheetConfig({required this.type});
}
