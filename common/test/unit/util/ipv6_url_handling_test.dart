/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/util/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expected results for one user input. A `null` URI means the input must be rejected.
class _Case {
  const _Case(this.input, {required this.http, required this.ws});

  final String input;
  final String? http;
  final String? ws;
}

const _cases = [
  _Case('::1', http: 'http://[::1]', ws: 'ws://[::1]/websocket'),
  _Case('[::1]:7125', http: 'http://[::1]:7125', ws: 'ws://[::1]:7125/websocket'),
  _Case('http://[::1]:7125/websocket', http: 'http://[::1]:7125/websocket', ws: 'ws://[::1]:7125/websocket'),
  _Case('fe80::1', http: 'http://[fe80::1]', ws: 'ws://[fe80::1]/websocket'),
  // RFC 6874: the zone ID delimiter has to be percent-encoded inside a URI
  _Case('fe80::1%wlan0', http: 'http://[fe80::1%25wlan0]', ws: 'ws://[fe80::1%25wlan0]/websocket'),
  // Documented: a bare IPv6 can not carry a port, the whole input is the address
  _Case('2001:db8::1:7125', http: 'http://[2001:db8::1:7125]', ws: 'ws://[2001:db8::1:7125]/websocket'),
  // The builders strip user info
  _Case('user:pw@2001:db8::1', http: 'http://[2001:db8::1]', ws: 'ws://[2001:db8::1]/websocket'),
  _Case('::ffff:192.168.1.10', http: 'http://[::ffff:192.168.1.10]', ws: 'ws://[::ffff:192.168.1.10]/websocket'),
  _Case('[2001:db8::1', http: null, ws: null),
  _Case('[:::]', http: null, ws: null),
];

void main() {
  group('IPv6 input table', () {
    for (final c in _cases) {
      group(c.input, () {
        test('buildMoonrakerHttpUri', () {
          expect(buildMoonrakerHttpUri(c.input)?.toString(), c.http == null ? isNull : Uri.parse(c.http!).toString());
        });

        test('buildMoonrakerWebSocketUri', () {
          expect(buildMoonrakerWebSocketUri(c.input)?.toString(), c.ws == null ? isNull : Uri.parse(c.ws!).toString());
        });
      });
    }
  });

  group('buildRemoteWebCamUri host matching', () {
    final remoteUri = Uri.parse('https://remote.example.com');

    for (final (machine, cam) in [
      ('http://[2001:DB8::1]:7125', 'http://[2001:db8::1]:8080/stream'),
      ('http://[::1]:7125', 'http://[0:0:0:0:0:0:0:1]:8080/stream'),
      ('http://[2001:db8::1]:7125', 'http://[2001:0db8::1]:8080/stream'),
    ]) {
      test('$machine matches $cam', () {
        final result = buildRemoteWebCamUri(remoteUri, Uri.parse(machine), Uri.parse(cam));
        expect(result.host, 'remote.example.com');
        expect(result.path, '/stream');
      });
    }

    test('different host is not rewritten', () {
      final cam = Uri.parse('http://[2001:db8::2]:8080/stream');
      expect(buildRemoteWebCamUri(remoteUri, Uri.parse('http://[2001:db8::1]'), cam), cam);
    });
  });

  group('zone ID round trip', () {
    // Zone IDs that look like percent-escapes (%12, %ab) must not be decoded into garbage
    for (final (input, zone) in [
      ('fe80::1%wlan0', 'wlan0'),
      ('fe80::1%12', '12'),
      ('fe80::1%ab', 'ab'),
      ('[fe80::1%12]:7125', '12'),
      ('[fe80::1%wlan0]:7125', 'wlan0'),
      ('[fe80::1%25wlan0]:7125', 'wlan0'), // already RFC 6874 encoded, must not be double-encoded
      ('ws://[fe80::1%25eth0]/websocket', 'eth0'),
    ]) {
      test('$input keeps zone $zone', () {
        final uri = buildMoonrakerWebSocketUri(input)!;
        expect(uri.host, 'fe80::1%25$zone');
        expect(Uri.parse(uri.toString()), uri, reason: 'survives toString/parse');
        expect(InternetAddress.tryParse(uri.host.replaceAll('%25', '%')), InternetAddress('fe80::1%$zone'));
      });
    }
  });
}
