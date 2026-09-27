/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/util/validator/custom_form_builder_validators.dart';

void main() {
  group('MobilerakerFormBuilderValidator.disallowMdns', () {
    final validator = MobilerakerFormBuilderValidator.disallowMdns<String>();

    group('Input with .local TLD', () {
      test('Valid URL with .local TLD', () {
        final result = validator('https://example.local');
        expect(result, isNotNull);
      });

      test('Valid URL with .local TLD and path', () {
        final result = validator('https://example.local/path');
        expect(result, isNotNull);
      });

      test('Valid URL with .local TLD, path, and fragment', () {
        final result = validator('https://example.local/path#fragment');
        expect(result, isNotNull);
      });

      test('Valid URL with .local TLD, path, and query parameters', () {
        final result = validator('https://example.local/path?param=value');
        expect(result, isNotNull);
      });

      test('Valid URL with .local TLD, path, query parameters, and fragment',
          () {
        final result =
            validator('https://example.local/path?param=value#fragment');
        expect(result, isNotNull);
      });

      test('Valid URL with .local TLD and omitted scheme', () {
        final result = validator('example.local');
        expect(result, isNotNull);
      });

      test('Valid URL with .local TLD, path, and omitted scheme', () {
        final result = validator('example.local/path');
        expect(result, isNotNull);
      });

      test(
          'Valid URL with .local TLD, path, query parameters, and omitted scheme',
          () {
        final result = validator('example.local/path?param=value');
        expect(result, isNotNull);
      });

      test(
          'Valid URL with .local TLD, path, query parameters, fragment, and omitted scheme',
          () {
        final result = validator('example.local/path?param=value#fragment');
        expect(result, isNotNull);
      });

      test('Valid URL with .local TLD, query parameters, and omitted scheme',
          () {
        final result = validator('example.local?param=value');
        expect(result, isNotNull);
      });

      test('Valid URL with .local TLD, fragment, and omitted scheme', () {
        final result = validator('example.local#fragment');
        expect(result, isNotNull);
      });
    });

    group('Input without .local TLD', () {
      test('Valid URL without .local TLD', () {
        final result = validator('https://example.com');
        expect(result, isNull);
      });

      test('Invalid URL with incorrect TLD', () {
        final result = validator('https://example.com');
        expect(result, isNull);
      });

      test('Null value', () {
        final result = validator(null);
        expect(result, isNull);
      });
    });
  });

  group('MobilerakerFormBuilderValidator.url', () {
    final validator = MobilerakerFormBuilderValidator.url<String>();

    for (final valid in [
      '192.1.1.1',
      '192.1.1.1:7125',
      'http://myprinter:7125/path',
      '[2001:db8::1]',
      '[2001:db8::1]:7125',
      'http://[2001:db8::1]:7125',
      'https://[2001:db8::1]:7125/moon',
      '2001:db8::1',
      'http://fd00::abcd',
      '[::1]:7125',
      '[fe80::1%25en0]:7125',
    ]) {
      test('accepts $valid', () => expect(validator(valid), isNull));
    }

    for (final invalid in [
      'ftp://[2001:db8::1]',
      '[2001:db8::1]:99999',
      '[zz::1]:7125',
      '[2001:db8::1',
      'not a url',
      'ftp://192.1.1.1',
    ]) {
      test('rejects $invalid', () => expect(validator(invalid), isNotNull));
    }

    test('requireProtocol rejects IPv6 without scheme',
        () => expect(MobilerakerFormBuilderValidator.url<String>(requireProtocol: true)('[::1]'), isNotNull));

    test('custom protocols are honored for IPv6', () {
      final v = MobilerakerFormBuilderValidator.url<String>(protocols: ['http', 'https', 'ftp']);
      expect(v('ftp://[::1]'), isNull);
    });
  });

  group('MobilerakerFormBuilderValidator.simpleUrl', () {
    final validator = MobilerakerFormBuilderValidator.simpleUrl<String>();

    for (final valid in [
      'myprinter',
      '192.1.1.1:7125',
      '[2001:db8::1]',
      '[2001:db8::1]:7125',
      '[fe80::1%en0]:7125',
      '2001:db8::1',
      '::1',
    ]) {
      test('accepts $valid', () => expect(validator(valid), isNull));
    }

    for (final invalid in ['[2001:db8::1]:0', 'http://[::1]', '[::1]/path', '2001:db8::1/path']) {
      test('rejects $invalid', () => expect(validator(invalid), isNotNull));
    }
  });
}
