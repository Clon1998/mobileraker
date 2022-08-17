import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

enum SnackbarType { error, warning, info }

final snackBarServiceProvider = Provider((ref) => SnackBarService(ref));

class SnackBarService {
  const SnackBarService(this.ref);

  final Ref ref;

  show(SnackBarConfig config) {}
}

class SnackBarConfig {
  final String? title;
  final String? body;
  final SnackbarType type;

  SnackBarConfig({this.title, this.body, this.type = SnackbarType.info});
}
