/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/util/extensions/object_extension.dart';
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
      final withScheme = hasScheme ? input : 'http://$input';
      final bracketed = bracketIPv6Host(withScheme);
      final uri = Uri.tryParse(bracketed);
      // Uri.host of an IPv6 literal is returned without brackets, therefore it contains a colon
      if (uri == null || !uri.host.contains(':')) return fallback(valueCandidate);

      // The bracketed form `[2001:db8::1:7125]` stays available as an explicit escape hatch
      if (bracketed != withScheme) {
        final suggestion = suggestBracketedIPv6Port(uri.host);
        if (suggestion != null) return errorText ?? tr('form_validators.ipv6_ambiguous_port', args: [suggestion]);
      }

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

        if (!_isSimpleHostPort(valueCandidate as String)) {
          return errorText ?? tr('form_validators.simple_url');
        }
      }
      return null;
    };
  }

  /// `host`, `host:port`, `[ipv6]`, `[ipv6]:port` or a bare `ipv6` (which can not carry a port).
  static bool _isSimpleHostPort(String value) {
    if (_isIPv6(value)) return true;

    final match = RegExp(r'^(?:([\w.-]+)|\[([^\]]+)\])(?::([0-9]+))?$').firstMatch(value);
    if (match == null) return false;

    final bracketContent = match.group(2);
    if (bracketContent != null && !_isIPv6(bracketContent)) return false;

    final port = match.group(3)?.let(int.parse);
    return port == null || (port > 0 && port <= 65535);
  }

  /// A bare IPv6 can not carry a port. If the last group of [ipv6Host] looks like a common port, the user most
  /// likely meant `[address]:port`, which is returned. E.g. `2001:db8::1:7125` -> `[2001:db8::1]:7125`.
  static String? suggestBracketedIPv6Port(String ipv6Host) {
    final address = ipv6Host.split('%').first;
    final lastGroup = address.split(':').last;
    if (!_commonPorts.contains(lastGroup)) return null;

    var host = address.substring(0, address.length - lastGroup.length);
    // Keep a trailing `::` (e.g. `::7125` -> `::`), otherwise drop the separating colon
    if (!host.endsWith('::')) host = host.substring(0, host.length - 1);
    return _isIPv6(host) ? '[$host]:$lastGroup' : null;
  }

  static bool _isIPv6(String value) => InternetAddress.tryParse(value)?.type == InternetAddressType.IPv6;

  static const _commonPorts = {'80', '443', '7125', '7130', '8080'};

  static FormFieldValidator<T> disallowMdns<T>({String? errorText}) {
    return (T? valueCandidate) {
      if (valueCandidate != null) {
        assert(valueCandidate is String);

        if (RegExp(r'^(?:\w+://)?[\w.-]+\.local(?:$|[#?][\w=]+|/[\w.-/#?=]*$)').hasMatch(valueCandidate as String)) {
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
