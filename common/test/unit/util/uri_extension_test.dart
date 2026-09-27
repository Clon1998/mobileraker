/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/util/extensions/uri_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Existing toHttpUri tests (as you provided)
  group('toHttpUri', () {
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

  group('toWebsocketUri', () {
    test('toWebsocketUri should convert http to ws', () {
      final uri = Uri.parse('http://example.com');
      final result = uri.toWebsocketUri();
      expect(result.scheme, 'ws');
    });

    test('toWebsocketUri should convert https to wss', () {
      final uri = Uri.parse('https://example.com');
      final result = uri.toWebsocketUri();
      expect(result.scheme, 'wss');
    });

    test('toWebsocketUri should convert ws to ws', () {
      final uri = Uri.parse('ws://example.com');
      final result = uri.toWebsocketUri();
      expect(result.scheme, 'ws');
    });

    test('toWebsocketUri should convert wss to wss', () {
      final uri = Uri.parse('wss://example.com');
      final result = uri.toWebsocketUri();
      expect(result.scheme, 'wss');
    });

    test('toWebsocketUri should convert other schemes to ws', () {
      final uri = Uri.parse('ftp://example.com');
      final result = uri.toWebsocketUri();
      expect(result.scheme, 'ws');
    });

    test('toWebsocketUri should remove standard ports', () {
      final uri = Uri.parse('http://example.com:80');
      final result = uri.toWebsocketUri();
      expect(result.port, 0);

      final uri2 = Uri.parse('https://example.com:443');
      final result2 = uri2.toWebsocketUri();
      expect(result2.port, 0);
    });

    test('toWebsocketUri should preserve non-standard ports', () {
      final uri = Uri.parse('http://example.com:8080');
      final result = uri.toWebsocketUri();
      expect(result.port, 8080);
    });
  });

  group('appendPath', () {
    test('appendPath should add path segments', () {
      final uri = Uri.parse('http://example.com');
      final result = uri.appendPath('users/profile');
      expect(result.pathSegments, ['users', 'profile']);
    });

    test('appendPath should handle existing path segments', () {
      final uri = Uri.parse('http://example.com/base');
      final result = uri.appendPath('users/profile');
      expect(result.pathSegments, ['base', 'users', 'profile']);
    });

    test('appendPath should handle empty path segments', () {
      final uri = Uri.parse('http://example.com');
      final result = uri.appendPath('///users///profile///');
      expect(result.pathSegments, ['users', 'profile']);
    });

    test('appendPath should handle uri with ending slash', () {
      final uri = Uri.parse('http://example.com/mystream/');
      final result = uri.appendPath('users');
      expect(result.pathSegments, ['mystream', 'users']);
    });
  });

  group('removePort', () {
    test('removePort should set port to 80 for http', () {
      final uri = Uri.parse('http://example.com:8080');
      final result = uri.removePort();
      expect(result.port, 80);
    });

    test('removePort should set port to 443 for https', () {
      final uri = Uri.parse('https://example.com:8443');
      final result = uri.removePort();
      expect(result.port, 443);
    });

    test('removePort should set port to 0 for other schemes', () {
      final uri = Uri.parse('ftp://example.com:21');
      final result = uri.removePort();
      expect(result.port, 0);
    });
  });

  group('removeUserInfo', () {
    test('removeUserInfo should remove user information', () {
      final uri = Uri.parse('http://user:pass@example.com');
      final result = uri.removeUserInfo();
      expect(result.userInfo, '');
    });

    test('removeUserInfo should not change uri without user info', () {
      final uri = Uri.parse('http://example.com');
      final result = uri.removeUserInfo();
      expect(result.userInfo, '');
    });
  });

  group('basicAuth', () {
    test('basicAuth should return null for empty user info', () {
      final uri = Uri.parse('http://example.com');
      final result = uri.basicAuth;
      expect(result, null);
    });

    test('basicAuth should return base64 encoded user info', () {
      final uri = Uri.parse('http://user:pass@example.com');
      final result = uri.basicAuth;
      final expectedAuth = base64Encode(utf8.encode('user:pass'));
      expect(result, 'Basic $expectedAuth');
    });
  });

  group('displayHost', () {
    test('IPv4', () => expect(Uri.parse('http://192.1.1.1:7125').displayHost, '192.1.1.1'));
    test('IPv6', () => expect(Uri.parse('http://[2001:db8::1]:7125').displayHost, '2001:db8::1'));
    test('IPv6 with zone id', () => expect(Uri.parse('http://[fe80::1%25en0]:7125').displayHost, 'fe80::1%en0'));
  });

  group('compactHost', () {
    test('IPv4 is untouched', () => expect(Uri.parse('http://192.168.1.42:7125').compactHost, '192.168.1.42'));
    test('hostname is untouched', () => expect(Uri.parse('http://my-very-long-printer-name.lan').compactHost, 'my-very-long-printer-name.lan'));
    test('short IPv6 is untouched', () => expect(Uri.parse('http://[fd00::5]').compactHost, 'fd00::5'));
    test('long IPv6 keeps last two groups',
        () => expect(Uri.parse('http://[2001:db8:85a3:0:1c2e:5678:9abc:1a2b]:7125').compactHost, '…:9abc:1a2b'));
    test('zone id is dropped', () => expect(Uri.parse('http://[fe80::1%25en0]').compactHost, 'fe80::1'));
    test('long link-local with zone id',
        () => expect(Uri.parse('http://[fe80::1c2e:5678:9abc:1a2b%25wlan0]').compactHost, '…:9abc:1a2b'));
  });
}
