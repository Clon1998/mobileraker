/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/widgets.dart';

extension BetterTextEditingController on TextEditingController {
  set textAndMoveCursor(String text) {
    this.text = text;
    selection = TextSelection.collapsed(offset: text.length);
  }
}
