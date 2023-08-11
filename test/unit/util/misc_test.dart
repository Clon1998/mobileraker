/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/util/misc.dart';

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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('192.1.1.1:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('192.1.1.1:123/to/moon/raker/');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('ws://192.1.1.1:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('ws://192.1.1.1:123/to/moon/raker/');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('https://192.1.1.1:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('wss://192.1.1.1:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('ftp://192.1.1.1:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('myprinter:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('myprinter:123/to/moon/raker/');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('ws://myprinter:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('ws://myprinter:123/to/moon/raker/');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('wss://myprinter:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('https://myprinter:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('ftp://myprinter:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('myprinter.co.com.zj.shop');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: 'myprinter.co.com.zj.shop',
              path: 'websocket',
            )));
      });

      test('host and port', () {
        var moonrakerUri =
            buildMoonrakerWebSocketUri('myprinter.co.com.zj.shop:222');
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
        var moonrakerUri = buildMoonrakerWebSocketUri(
            'myprinter.co.com.zj.shop:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerWebSocketUri('ws://myprinter.co.com.zj.shop');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'ws',
              host: 'myprinter.co.com.zj.shop',
              path: 'websocket',
            )));
      });

      test('protocol, host and port', () {
        var moonrakerUri =
            buildMoonrakerWebSocketUri('ws://myprinter.co.com.zj.shop:123');
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
        var moonrakerUri = buildMoonrakerWebSocketUri(
            'ws://myprinter.co.com.zj.shop:123/to/moon/raker');
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
        var moonrakerUri = buildMoonrakerWebSocketUri(
            'wss://myprinter.co.com.zj.shop:123/to/moon/raker');
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
        var moonrakerUri = buildMoonrakerWebSocketUri(
            'https://myprinter.co.com.zj.shop:123/to/moon/raker');
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
        var moonrakerUri = buildMoonrakerWebSocketUri(
            'ftp://myprinter.co.com.zj.shop:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('192.1.1.1:123/to/moon/raker/');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('ws://192.1.1.1:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('ws://192.1.1.1:123/to/moon/raker/');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('https://192.1.1.1:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('wss://192.1.1.1:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('ftp://192.1.1.1:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('myprinter:123/to/moon/raker/');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('ws://myprinter:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('ws://myprinter:123/to/moon/raker/');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('wss://myprinter:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('https://myprinter:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('ftp://myprinter:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('myprinter.co.com.zj.shop:222');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 222,
              host: 'myprinter.co.com.zj.shop',
            )));
      });

      test('host, port and path', () {
        var moonrakerUri =
            buildMoonrakerHttpUri('myprinter.co.com.zj.shop:123/to/moon/raker');
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
        var moonrakerUri =
            buildMoonrakerHttpUri('ws://myprinter.co.com.zj.shop');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              host: 'myprinter.co.com.zj.shop',
            )));
      });

      test('protocol, host and port', () {
        var moonrakerUri =
            buildMoonrakerHttpUri('ws://myprinter.co.com.zj.shop:123');
        expect(
            moonrakerUri,
            equals(Uri(
              scheme: 'http',
              port: 123,
              host: 'myprinter.co.com.zj.shop',
            )));
      });

      test('protocol, port and path', () {
        var moonrakerUri = buildMoonrakerHttpUri(
            'ws://myprinter.co.com.zj.shop:123/to/moon/raker');
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
        var moonrakerUri = buildMoonrakerHttpUri(
            'wss://myprinter.co.com.zj.shop:123/to/moon/raker');
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
        var moonrakerUri = buildMoonrakerHttpUri(
            'https://myprinter.co.com.zj.shop:123/to/moon/raker');
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
        var moonrakerUri = buildMoonrakerHttpUri(
            'ftp://myprinter.co.com.zj.shop:123/to/moon/raker');
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
}
