/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:hooks_riverpod/hooks_riverpod.dart';

extension MobilerakerProviderExtension on ProviderBase {
  String toIdentityString() {
    var leading = '';
    if (from != null) {
      leading = '($argument|${from.toString()}#${from.hashCode})';
    }

    var trailing = '';
    if (name != null) {
      trailing = '$name:';
    }

    return '$trailing$runtimeType#${identityHashCode(this)}$leading';
  }
}
