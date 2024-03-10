/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('test buildMoonrakerWebSocketUri()', () {
    group('for bad input', () {
      test('input is empty', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('');
        expect(moonrakerUri, isNull);
      });

      test('input is whitespaces', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('   ');
        expect(moonrakerUri, isNull);
      });
    });

    group('for ip input', () {
      test('host', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('192.1.1.1');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: '192.1.1.1',
              path: 'websocket',
            )));
      });

      test('host and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('192.1.1.1/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: '192.1.1.1',
              path: 'websocket',
            )));
      });

      test('host and port', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('192.1.1.1:222');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 222,
              host: '192.1.1.1',
              path: 'websocket',
            )));
      });

      test('host, port and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('192.1.1.1:123/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: '192.1.1.1',
              path: 'websocket',
            )));
      });

      test('host, port and path', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('192.1.1.1:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('host, port, path and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('192.1.1.1:123/to/moon/raker/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('protocol and host ', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://192.1.1.1');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: '192.1.1.1',
              path: 'websocket',
            )));
      });
      test('protocol, host and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://192.1.1.1/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: '192.1.1.1',
              path: 'websocket',
            )));
      });

      test('protocol, host and port', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://192.1.1.1:123');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: '192.1.1.1',
              path: 'websocket',
            )));
      });

      test('protocol, host, port and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://192.1.1.1:123/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: '192.1.1.1',
              path: 'websocket',
            )));
      });

      test('protocol, port and path', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://192.1.1.1:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('protocol, port, path and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://192.1.1.1:123/to/moon/raker/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('https', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('https://192.1.1.1:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'wss',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('wss', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('wss://192.1.1.1:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'wss',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('Other protocol', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ftp://192.1.1.1:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });
    });

    group('for url without TLD', () {
      test('host', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('myprinter');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: 'myprinter',
              path: 'websocket',
            )));
      });

      test('host ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('myprinter/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: 'myprinter',
              path: 'websocket',
            )));
      });

      test('host and port', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('myprinter:222');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 222,
              host: 'myprinter',
              path: 'websocket',
            )));
      });

      test('host, port and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('myprinter:222/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 222,
              host: 'myprinter',
              path: 'websocket',
            )));
      });

      test('host, port and path', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('myprinter:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('host, port, path and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('myprinter:123/to/moon/raker/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('protocol and host ', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://myprinter');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: 'myprinter',
              path: 'websocket',
            )));
      });
      test('protocol, host and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://myprinter/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: 'myprinter',
              path: 'websocket',
            )));
      });

      test('protocol, host and port ', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://myprinter:25');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: 'myprinter',
              port: 25,
              path: 'websocket',
            )));
      });
      test('protocol, host, port and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://myprinter:25/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: 'myprinter',
              port: 25,
              path: 'websocket',
            )));
      });

      test('protocol, port and path', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://myprinter:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('protocol, port, path and ending with /', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://myprinter:123/to/moon/raker/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('wss', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('wss://myprinter:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'wss',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('https', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('https://myprinter:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'wss',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('Other protocol', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ftp://myprinter:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });
    });

    group('for url with TLD', () {
      test('host', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('myprinter.co.com.zj.shop');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: 'myprinter.co.com.zj.shop',
              path: 'websocket',
            )));
      });

      test('host and port', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('myprinter.co.com.zj.shop:222');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 222,
              host: 'myprinter.co.com.zj.shop',
              path: 'websocket',
            )));
      });

      test('host, port and path', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('myprinter.co.com.zj.shop:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'to/moon/raker',
            )));
      });

      test('protocol and host ', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://myprinter.co.com.zj.shop');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: 'myprinter.co.com.zj.shop',
              path: 'websocket',
            )));
      });

      test('protocol, host and port', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://myprinter.co.com.zj.shop:123');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'websocket',
            )));
      });

      test('protocol, port and path', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ws://myprinter.co.com.zj.shop:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'to/moon/raker',
            )));
      });

      test('wss', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('wss://myprinter.co.com.zj.shop:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'wss',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'to/moon/raker',
            )));
      });

      test('https', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('https://myprinter.co.com.zj.shop:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'wss',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'to/moon/raker',
            )));
      });

      test('Other protocol', () {
        var moonrakerUri = buildMoonrakerWebSocketUri('ftp://myprinter.co.com.zj.shop:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'to/moon/raker',
            )));
      });
    });
  });

  group('test buildMoonrakerHttpUri', () {
    group('for bad input', () {
      test('input is empty', () {
        var moonrakerUri = buildMoonrakerHttpUri('');
        expect(moonrakerUri, isNull);
      });

      test('input is whitespaces', () {
        var moonrakerUri = buildMoonrakerHttpUri('   ');
        expect(moonrakerUri, isNull);
      });
    });

    group('for ip input', () {
      test('host', () {
        var moonrakerUri = buildMoonrakerHttpUri('192.1.1.1');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: '192.1.1.1',
            )));
      });

      test('host and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('192.1.1.1/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: '192.1.1.1',
            )));
      });

      test('host and port', () {
        var moonrakerUri = buildMoonrakerHttpUri('192.1.1.1:222');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 222,
              host: '192.1.1.1',
            )));
      });

      test('host, port and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('192.1.1.1:123/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: '192.1.1.1',
            )));
      });

      test('host, port and path', () {
        var moonrakerUri = buildMoonrakerHttpUri('192.1.1.1:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('host, port, path and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('192.1.1.1:123/to/moon/raker/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('protocol and host ', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://192.1.1.1');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: '192.1.1.1',
            )));
      });
      test('protocol, host and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://192.1.1.1/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: '192.1.1.1',
            )));
      });

      test('protocol, host and port', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://192.1.1.1:123');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: '192.1.1.1',
            )));
      });

      test('protocol, host, port and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://192.1.1.1:123/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: '192.1.1.1',
            )));
      });

      test('protocol, port and path', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://192.1.1.1:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('protocol, port, path and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://192.1.1.1:123/to/moon/raker/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('https', () {
        var moonrakerUri = buildMoonrakerHttpUri('https://192.1.1.1:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'https',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('wss', () {
        var moonrakerUri = buildMoonrakerHttpUri('wss://192.1.1.1:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'https',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });

      test('Other protocol', () {
        var moonrakerUri = buildMoonrakerHttpUri('ftp://192.1.1.1:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: '192.1.1.1',
              path: 'to/moon/raker',
            )));
      });
    });

    group('for url without TLD', () {
      test('host', () {
        var moonrakerUri = buildMoonrakerHttpUri('myprinter');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: 'myprinter',
            )));
      });

      test('host ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('myprinter/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: 'myprinter',
            )));
      });

      test('host and port', () {
        var moonrakerUri = buildMoonrakerHttpUri('myprinter:222');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 222,
              host: 'myprinter',
            )));
      });

      test('host, port and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('myprinter:222/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 222,
              host: 'myprinter',
            )));
      });

      test('host, port and path', () {
        var moonrakerUri = buildMoonrakerHttpUri('myprinter:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('host, port, path and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('myprinter:123/to/moon/raker/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('protocol and host ', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://myprinter');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: 'myprinter',
            )));
      });
      test('protocol, host and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://myprinter/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: 'myprinter',
            )));
      });

      test('protocol, host and port ', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://myprinter:25');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: 'myprinter',
              port: 25,
            )));
      });
      test('protocol, host, port and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://myprinter:25/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: 'myprinter',
              port: 25,
            )));
      });

      test('protocol, port and path', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://myprinter:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('protocol, port, path and ending with /', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://myprinter:123/to/moon/raker/');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('wss', () {
        var moonrakerUri = buildMoonrakerHttpUri('wss://myprinter:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'https',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('https', () {
        var moonrakerUri = buildMoonrakerHttpUri('https://myprinter:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'https',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });

      test('Other protocol', () {
        var moonrakerUri = buildMoonrakerHttpUri('ftp://myprinter:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: 'myprinter',
              path: 'to/moon/raker',
            )));
      });
    });

    group('for url with TLD', () {
      test('host', () {
        var moonrakerUri = buildMoonrakerHttpUri('myprinter.co.com.zj.shop');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: 'myprinter.co.com.zj.shop',
            )));
      });

      test('host and port', () {
        var moonrakerUri = buildMoonrakerHttpUri('myprinter.co.com.zj.shop:222');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 222,
              host: 'myprinter.co.com.zj.shop',
            )));
      });

      test('host, port and path', () {
        var moonrakerUri = buildMoonrakerHttpUri('myprinter.co.com.zj.shop:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'to/moon/raker',
            )));
      });

      test('protocol and host ', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://myprinter.co.com.zj.shop');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: 'myprinter.co.com.zj.shop',
            )));
      });

      test('protocol, host and port', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://myprinter.co.com.zj.shop:123');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
            )));
      });

      test('protocol, port and path', () {
        var moonrakerUri = buildMoonrakerHttpUri('ws://myprinter.co.com.zj.shop:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'to/moon/raker',
            )));
      });

      test('wss', () {
        var moonrakerUri = buildMoonrakerHttpUri('wss://myprinter.co.com.zj.shop:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'https',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'to/moon/raker',
            )));
      });

      test('https', () {
        var moonrakerUri = buildMoonrakerHttpUri('https://myprinter.co.com.zj.shop:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'https',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'to/moon/raker',
            )));
      });

      test('Other protocol', () {
        var moonrakerUri = buildMoonrakerHttpUri('ftp://myprinter.co.com.zj.shop:123/to/moon/raker');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
              path: 'to/moon/raker',
            )));
      });
    });
  });

  group('test buildWebCamUri', () {
    group('Relative Cam URI', () {
      test('machine(WS, IP) and cam(PATH)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('ws://192.1.1.0'), Uri(path: '/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('http://192.1.1.0/webcam/webrtc'));
      });

      test(
        'machine(WS, IP, PORT) and cam(PATH)',
        () {
          var moonrakerUri = buildWebCamUri(Uri.parse('ws://192.1.1.0:212'), Uri(path: '/webcam/webrtc'));
          expect(moonrakerUri, Uri.parse('http://192.1.1.0:212/webcam/webrtc'));
        },
      );

      test(
        'machine(WS, IP, PORT) and cam(PATH) (legacy)',
        () {
          var moonrakerUri = buildWebCamUri(Uri.parse('ws://192.1.1.0:212'), Uri(path: '/webcam/webrtc'));
          expect(moonrakerUri, Uri.parse('http://192.1.1.0/webcam/webrtc'));
        },
        skip: 'The test was prior to K1. Now I expect the port to be kept since I switched to the http endpoint',
      );

      test('machine(WSS, IP) and cam(PATH)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('wss://192.1.1.0'), Uri(path: '/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('https://192.1.1.0/webcam/webrtc'));
      });

      test('machine(WSS, IP, PORT) and cam(PATH)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('wss://192.1.1.0:212'), Uri(path: '/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('https://192.1.1.0:212/webcam/webrtc'));
      });

      test(
        'machine(WSS, IP, PORT) and cam(PATH) (legacy)',
        () {
          var moonrakerUri = buildWebCamUri(Uri.parse('wss://192.1.1.0:212'), Uri(path: '/webcam/webrtc'));
          expect(moonrakerUri, Uri.parse('https://192.1.1.0/webcam/webrtc'));
        },
        skip: 'The test was prior to K1. Now I expect the port to be kept since I switched to the http endpoint',
      );

      ///
      test('machine(WS, DNS) and cam(PATH)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('ws://mobileraker.test'), Uri(path: '/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('http://mobileraker.test/webcam/webrtc'));
      });

      test('machine(WS, DNS, PORT) and cam(PATH)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('ws://mobileraker.test:212'), Uri(path: '/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('http://mobileraker.test:212/webcam/webrtc'));
      });

      test(
        'machine(WS, DNS, PORT) and cam(PATH) (legacy)',
        () {
          var moonrakerUri = buildWebCamUri(Uri.parse('ws://mobileraker.test:212'), Uri(path: '/webcam/webrtc'));
          expect(moonrakerUri, Uri.parse('http://mobileraker.test/webcam/webrtc'));
        },
        skip: 'The test was prior to K1. Now I expect the port to be kept since I switched to the http endpoint',
      );

      test('machine(WSS, DNS) and cam(PATH)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('wss://mobileraker.test'), Uri(path: '/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('https://mobileraker.test/webcam/webrtc'));
      });

      test('machine(WSS, DNS, PORT) and cam(PATH)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('wss://mobileraker.test:212'), Uri(path: '/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('https://mobileraker.test:212/webcam/webrtc'));
      });

      test(
        'machine(WSS, DNS, PORT) and cam(PATH) (legacy)',
        () {
          var moonrakerUri = buildWebCamUri(Uri.parse('wss://mobileraker.test:212'), Uri(path: '/webcam/webrtc'));
          expect(moonrakerUri, Uri.parse('https://mobileraker.test/webcam/webrtc'));
        },
        skip: 'The test was prior to K1. Now I expect the port to be kept since I switched to the http endpoint',
      );

      test(
        'Moonraker WS port changes to default http port',
        () {
          var moonrakerUri = buildWebCamUri(Uri.parse('ws://mobileraker.test:7125'), Uri(path: '/webcam/webrtc'));
          expect(moonrakerUri, Uri.parse('http://mobileraker.test:80/webcam/webrtc'));
        },
      );

      test(
        'Moonraker WSS port changes to default http port',
        () {
          var moonrakerUri = buildWebCamUri(Uri.parse('wss://mobileraker.test:7125'), Uri(path: '/webcam/webrtc'));
          expect(moonrakerUri, Uri.parse('https://mobileraker.test:443/webcam/webrtc'));
        },
      );
    });

    group('Absolut Cam URI', () {
      test('machine(WS, IP) and cam(HTTP, IP)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('http://192.168.178.135'), Uri.parse('http://192.1.1.0'));
        expect(moonrakerUri, Uri.parse('http://192.1.1.0'));
      });

      test('machine(WS, IP, PORT) and cam(HTTP, IP, PATH)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('ws://192.1.1.0:212'), Uri.parse('http://192.1.1.0/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('http://192.1.1.0/webcam/webrtc'));
      });

      test('machine(WSS, IP) and cam(HTTP, IP, PORT)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('wss://192.1.1.0'), Uri.parse('http://192.1.1.0:212'));
        expect(moonrakerUri, Uri.parse('http://192.1.1.0:212'));
      });

      test('machine(WSS, IP, PORT) and cam(HTTP, IP, PORT, Path)', () {
        var moonrakerUri =
            buildWebCamUri(Uri.parse('wss://192.1.1.0:212'), Uri.parse('http://192.1.1.0:212/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('http://192.1.1.0:212/webcam/webrtc'));
      });

      test('machine(WS, DNS) and cam(HTTP, IP)', () {
        var moonrakerUri = buildWebCamUri(Uri.parse('http://mobileraker.test'), Uri.parse('http://192.1.1.0'));
        expect(moonrakerUri, Uri.parse('http://192.1.1.0'));
      });

      test('machine(WS, DNS, PORT) and cam(HTTP, IP, PATH)', () {
        var moonrakerUri =
            buildWebCamUri(Uri.parse('ws://mobileraker.test:212'), Uri.parse('http://192.1.1.0/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('http://192.1.1.0/webcam/webrtc'));
      });

      test('machine(WS, DNS, PORT,PATH) and cam(HTTP, IP, PATH)', () {
        var moonrakerUri =
            buildWebCamUri(Uri.parse('ws://mobileraker.test:212/test'), Uri.parse('http://192.1.1.0/webcam/webrtc'));
        expect(moonrakerUri, Uri.parse('http://192.1.1.0/webcam/webrtc'));
      });
    });
  });

  group('test buildRemoteWebCamUri', () {
    test('Relative cam and matches machine URI', () {
      var moonrakerUri = buildRemoteWebCamUri(
        Uri.parse('http://my.remote'),
        Uri.parse('ws://192.1.1.0:212/test'),
        Uri.parse('/webcam/webrtc'),
      );
      expect(moonrakerUri, Uri.parse('http://my.remote/webcam/webrtc'));
    });

    test('Relative cam and matches machine URI remote uri has port', () {
      var moonrakerUri = buildRemoteWebCamUri(
        Uri.parse('http://my.remote:22'),
        Uri.parse('ws://192.1.1.0:212/test'),
        Uri.parse('/webcam/webrtc'),
      );
      expect(moonrakerUri, Uri.parse('http://my.remote:22/webcam/webrtc'));
    });

    test('Absolut cam and matches machine URI', () {
      var moonrakerUri = buildRemoteWebCamUri(
        Uri.parse('http://my.remote'),
        Uri.parse('ws://192.1.1.0:212/test'),
        Uri.parse('http://192.1.1.0/webcam/webrtc'),
      );
      expect(moonrakerUri, Uri.parse('http://my.remote/webcam/webrtc'));
    });

    test('Absolut cam and not matches machine URI', () {
      var moonrakerUri = buildRemoteWebCamUri(
        Uri.parse('http://my.remote'),
        Uri.parse('ws://192.1.1.1:212/test'),
        Uri.parse('http://192.1.1.0/webcam/webrtc'),
      );
      expect(moonrakerUri, Uri.parse('http://192.1.1.0/webcam/webrtc'));
    });

    test('Absolut cam with PORT and matches machine URI', () {
      var moonrakerUri = buildRemoteWebCamUri(
        Uri.parse('http://my.remote'),
        Uri.parse('ws://192.1.1.0:212/test'),
        Uri.parse('http://192.1.1.0:4444/webcam/webrtc'),
      );
      expect(moonrakerUri, Uri.parse('http://my.remote:4444/webcam/webrtc'));
    });
  });
}
