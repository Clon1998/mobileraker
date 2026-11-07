/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/widgets.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';

/// Reads the numbers typed into the Spoolman forms.
///
/// The forms show numbers in the user's locale ("19,99" in German), so the locale's decimal separator is accepted
/// next to the dot. Grouping separators are not, the fields never show them.
class FormNumberParser {
  FormNumberParser(String locale) : _decimalSeparator = NumberFormat('0.##', locale).symbols.DECIMAL_SEP;

  final String _decimalSeparator;

  /// The number in [text], null if it is empty or not a number.
  double? tryParse(String? text) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final normalized = _decimalSeparator == '.' ? trimmed : trimmed.replaceAll(_decimalSeparator, '.');
    // double.tryParse also takes "NaN", "Infinity" and exponents, none of them is a value for these fields.
    if (!RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)$').hasMatch(normalized)) return null;
    return double.tryParse(normalized);
  }

  /// Fails for text that is not a number. Empty text passes, unless [required] is set.
  FormFieldValidator<String> validator({bool required = false}) {
    return (text) {
      if (text == null || text.trim().isEmpty) {
        return required ? FormBuilderLocalizations.current.requiredErrorText : null;
      }
      return tryParse(text) == null ? FormBuilderLocalizations.current.numericErrorText : null;
    };
  }
}
