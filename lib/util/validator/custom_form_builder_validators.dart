/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

final class MobilerakerFormBuilderValidator {
  static FormFieldValidator<T> simpleUrl<T>({String? errorText}) {
    return (T? valueCandidate) {
      if (valueCandidate != null) {
        assert(valueCandidate is String);

        if (!RegExp(r'^[\w.-]+(?::(?!0)[1-9][0-9]*)?$').hasMatch(valueCandidate as String)) {
          return errorText ?? tr('form_validators.simple_url');
        }
      }
      return null;
    };
  }

  static FormFieldValidator<T> disallowMdns<T>({String? errorText}) {
    return (T? valueCandidate) {
      if (valueCandidate != null) {
        assert(valueCandidate is String);

        if (RegExp(r'^(?:\w+://)?[\w.-]+.local(?:$|[#?][\w=]+|/[\w.-/#?=]*$)')
            .hasMatch(valueCandidate as String)) {
          return errorText ?? tr('form_validators.disallow_mdns');
        }
      }
      return null;
    };
  }
}
