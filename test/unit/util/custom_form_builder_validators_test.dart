/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
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
}
