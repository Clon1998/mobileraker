import 'package:hooks_riverpod/hooks_riverpod.dart';

extension Precision on ProviderBase {
  String toIdentityString() {
    var leading = '';
    if (from != null) {
      leading = '($argument)';
    }

    var trailing = '';
    if (name != null) {
      trailing = '$name:';
    }

    return '$trailing$runtimeType#${identityHashCode(this)}$leading';
  }
}
