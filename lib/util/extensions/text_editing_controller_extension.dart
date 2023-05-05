
import 'package:flutter/widgets.dart';

extension BetterTextEditingController on TextEditingController {
   set textAndMoveCursor(String text) {
     this.text = text;
     selection = TextSelection.collapsed(offset: text.length);
   }
}