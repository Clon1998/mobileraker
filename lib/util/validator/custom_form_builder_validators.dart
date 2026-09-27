/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

final class MobilerakerFormBuilderValidator {
  /// Drop-in replacement for [FormBuilderValidators.url] that additionally accepts IPv6 hosts,
  /// either bracketed (`[2001:db8::1]:7125`) or bare without a port (`2001:db8::1`).
  /// Non-IPv6 input is delegated to [FormBuilderValidators.url] unchanged.
  static FormFieldValidator<T> url<T>({
    List<String> protocols = const ['http', 'https'],
    bool requireTld = false,
    bool requireProtocol = false,
    bool checkNullOrEmpty = true,
    String? errorText,
  }) {
    final fallback = FormBuilderValidators.url(
      protocols: protocols,
      requireTld: requireTld,
      requireProtocol: requireProtocol,
      checkNullOrEmpty: checkNullOrEmpty,
      errorText: errorText,
    );

    return (T? valueCandidate) {
      final input = (valueCandidate as String?)?.trim();
      if (input == null || input.isEmpty) return fallback(valueCandidate);

      final hasScheme = input.contains('://');
      final uri = Uri.tryParse(bracketIPv6Host(hasScheme ? input : 'http://$input'));
      // Uri.host of an IPv6 literal is returned without brackets, therefore it contains a colon
      if (uri == null || !uri.host.contains(':')) return fallback(valueCandidate);

      if ((requireProtocol && !hasScheme) || !protocols.contains(uri.scheme.toLowerCase())) {
        return errorText ?? FormBuilderLocalizations.current.urlErrorText;
      }
      if (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) {
        return errorText ?? FormBuilderLocalizations.current.urlErrorText;
      }
      return null;
    };
  }

  static FormFieldValidator<T> simpleUrl<T>({String? errorText}) {
    return (T? valueCandidate) {
      if (valueCandidate != null) {
        assert(valueCandidate is String);

        if (!RegExp(
              r'^(?:[\w.-]+|\[[0-9a-fA-F:.]+(?:%[\w.-]+)?\])(?::(?!0)[1-9][0-9]*)?$',
            ).hasMatch(valueCandidate as String) &&
            InternetAddress.tryParse(valueCandidate)?.type != InternetAddressType.IPv6) {
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

        if (RegExp(r'^(?:\w+://)?[\w.-]+.local(?:$|[#?][\w=]+|/[\w.-/#?=]*$)').hasMatch(valueCandidate as String)) {
          return errorText ?? tr('form_validators.disallow_mdns');
        }
      }
      return null;
    };
  }

  static FormFieldValidator<T> sideEffect<T>(
    FormFieldValidator<T> validator, {
    required Function(String? errors) sideEffect,
  }) {
    return (T? valueCandidate) {
      final res = validator.call(valueCandidate);

      sideEffect(res);

      return res;
    };
  }
}
