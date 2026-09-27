/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/misc.dart';
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

      test('Valid URL with .local TLD, path, query parameters, and fragment', () {
        final result = validator('https://example.local/path?param=value#fragment');
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

      test('Valid URL with .local TLD, path, query parameters, and omitted scheme', () {
        final result = validator('example.local/path?param=value');
        expect(result, isNotNull);
      });

      test('Valid URL with .local TLD, path, query parameters, fragment, and omitted scheme', () {
        final result = validator('example.local/path?param=value#fragment');
        expect(result, isNotNull);
      });

      test('Valid URL with .local TLD, query parameters, and omitted scheme', () {
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

    test(
      'requireProtocol rejects IPv6 without scheme',
      () => expect(MobilerakerFormBuilderValidator.url<String>(requireProtocol: true)('[::1]'), isNotNull),
    );

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

  group('IPv6 input table (review)', () {
    final url = MobilerakerFormBuilderValidator.url<String>();
    final simple = MobilerakerFormBuilderValidator.simpleUrl<String>();

    // input -> (accepted by url, accepted by simpleUrl)
    const table = <String, (bool, bool)>{
      '::1': (true, true),
      '[::1]:7125': (true, true),
      'http://[::1]:7125/websocket': (true, false),
      'fe80::1': (true, true),
      'fe80::1%wlan0': (true, true),
      '2001:db8::1:7125': (false, true), // url rejects it with the "did you mean [..]:port" hint
      '[2001:db8::1:7125]': (true, true), // explicit escape hatch for an address ending in 7125
      '2001:db8::1:abcd': (true, true),
      'user:pw@2001:db8::1': (true, false),
      '::ffff:192.168.1.10': (true, true),
      '[2001:db8::1': (false, false),
      '[:::]': (false, false),
    };

    table.forEach((input, expected) {
      final (urlOk, simpleOk) = expected;
      test('url ${urlOk ? 'accepts' : 'rejects'} $input', () => expect(url(input), urlOk ? isNull : isNotNull));
      test(
        'simpleUrl ${simpleOk ? 'accepts' : 'rejects'} $input',
        () => expect(simple(input), simpleOk ? isNull : isNotNull),
      );
    });
  });

  group('simpleUrl bracketed form strictness (review)', () {
    final simple = MobilerakerFormBuilderValidator.simpleUrl<String>();

    for (final invalid in ['[:::]', '[....]', '[1]', '[::1]:99999', '[::1]:65536', 'myprinter:70000']) {
      test('rejects $invalid', () => expect(simple(invalid), isNotNull));
    }

    for (final valid in ['[::1]:65535', 'myprinter:1']) {
      test('accepts $valid', () => expect(simple(valid), isNull));
    }
  });

  group('disallowMdns dot before local (review)', () {
    final validator = MobilerakerFormBuilderValidator.disallowMdns<String>();

    test('printerlocal is not an mDNS address', () => expect(validator('printerlocal'), isNull));
    test(
      'http://printerlocal/path is not an mDNS address',
      () => expect(validator('http://printerlocal/path'), isNull),
    );
    test('printer.local is still rejected', () => expect(validator('printer.local'), isNotNull));
  });

  group('url IPv6 port hint', () {
    final url = MobilerakerFormBuilderValidator.url<String>();

    for (final (input, suggestion) in [
      ('2001:db8::1:7125', '[2001:db8::1]:7125'),
      ('http://fd00::5:80', '[fd00::5]:80'),
      ('::7125', '[::]:7125'),
      ('fe80::1:8080', '[fe80::1]:8080'),
    ]) {
      test('$input is rejected with suggestion $suggestion', () {
        expect(url(input), isNotNull);
        expect(
          MobilerakerFormBuilderValidator.suggestBracketedIPv6Port(
            Uri.parse('http://${bracketIPv6Host(input.split('://').last)}').host,
          ),
          suggestion,
        );
      });
    }

    test('no hint if the remaining address would be invalid', () => expect(url('1:2:3:4:5:6:7:80'), isNull));
    test('no hint for bracketed input', () => expect(url('[2001:db8::1:7125]'), isNull));
    test('no hint for non-port last group', () => expect(url('2001:db8::1:7126'), isNull));
  });
}
