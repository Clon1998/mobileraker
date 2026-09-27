/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/util/extensions/string_extension.dart';

extension MobilerakerUri on Uri {
  Uri appendPath(String pathToAppend) {
    final List<String> adjustedSegments = pathSegments.toList();
    if (adjustedSegments.isNotEmpty && adjustedSegments.last.isEmpty) {
      adjustedSegments.removeLast();
    }
    adjustedSegments.addAll(pathToAppend.split('/').where((element) => element.isNotEmpty));

    return replace(pathSegments: adjustedSegments);
  }

  Uri removePort() => replace(
          port: switch (scheme) {
        'http' => 80,
        'https' => 443,
        _ => 0,
      });

  Uri removeUserInfo() => replace(userInfo: '');

  Uri toWebsocketUri() {
    return replace(
        scheme: switch (scheme) {
          'http' || 'ws' => 'ws',
          'https' || 'wss' => 'wss',
          _ => 'ws',
        },
        port: switch (port) {
          80 || 443 => 0,
          _ => port,
        });
  }

  Uri toHttpUri() {
    return replace(
        scheme: switch (scheme) {
          'http' || 'ws' => 'http',
          'https' || 'wss' => 'https',
          _ => 'http',
        },
        port: switch (port) {
          0 => switch (scheme) {
              'http' || 'ws' => 80,
              'https' || 'wss' => 443,
              _ => 0,
            },
          _ => port,
        });
  }

  /// The host as it should be shown to users. [Uri.host] keeps the zone ID of a
  /// link-local IPv6 address percent-encoded (`fe80::1%25en0`), this decodes it (`fe80::1%en0`).
  String get displayHost => host.replaceAll('%25', '%');

  /// A shortened [displayHost] for space constrained places like headers and cards.
  /// Long IPv6 addresses are reduced to their last two groups (`…:9abc:1a2b`), as the leading
  /// network prefix is usually shared by all devices in the same network. The zone ID is dropped.
  /// Every other host is returned as [displayHost].
  String get compactHost {
    // IPv6 literals are the only hosts containing a colon
    if (!host.contains(':')) return displayHost;

    final address = host.split('%').first;
    if (address.length <= 20) return address;

    final groups = address.split(':');
    return '…:${groups.sublist(groups.length - 2).join(':')}';
  }

  /// Hide the userInfo to ensure we can safely log the uri
  Uri obfuscate() => replace(userInfo: userInfo.obfuscate());

  String? get basicAuth {
    if (userInfo.isNotEmpty) {
      String auth = base64Encode(utf8.encode(userInfo));
      return 'Basic $auth';
    }
    return null;
  }
}
