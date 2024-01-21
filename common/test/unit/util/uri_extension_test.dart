/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/uri_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UriExtension', () {
    test('toHttpUri should return http scheme for http and ws schemes', () {
      final uri = Uri.parse('ws://example.com');
      final result = uri.toHttpUri();
      expect(result.scheme, 'http');

      final uri2 = Uri.parse('http://example.com');
      final result2 = uri2.toHttpUri();
      expect(result2.scheme, 'http');
    });

    test('toHttpUri should return https scheme for https and wss schemes', () {
      final uri = Uri.parse('wss://example.com');
      final result = uri.toHttpUri();
      expect(result.scheme, 'https');
      final uri2 = Uri.parse('https://example.com');
      final result2 = uri2.toHttpUri();
      expect(result2.scheme, 'https');
    });

    test('toHttpUri should return http scheme for non http/ws/https/wss schemes', () {
      final uri = Uri.parse('ftp://example.com');
      final result = uri.toHttpUri();
      expect(result.scheme, 'http');
    });

    test('toHttpUri should return port 80 for http and ws schemes when original port is 0', () {
      final uri = Uri.parse('http://example.com');
      final result = uri.toHttpUri();
      expect(result.port, 80);
    });

    test('toHttpUri should return port 443 for https and wss schemes when original port is 0', () {
      final uri = Uri.parse('https://example.com');
      final result = uri.toHttpUri();
      expect(result.port, 443);
    });

    test('toHttpUri should return port 0 for non http/ws/https/wss schemes when original port is 0', () {
      final uri = Uri.parse('ftp://example.com');
      final result = uri.toHttpUri();
      expect(result.port, 0);
    });

    test('toHttpUri should return original port when original port is not 0', () {
      final uri = Uri.parse('http://example.com:8080');
      final result = uri.toHttpUri();
      expect(result.port, 8080);
    });
  });
}
