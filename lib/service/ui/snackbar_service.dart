import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';

enum SnackbarType { error, warning, info }

final snackBarServiceProvider = Provider((ref) => SnackBarService(ref));

class SnackBarService {
  const SnackBarService(this.ref);

  final Ref ref;

  show(SnackBarConfig config) {
    var context =
        ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext!;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: Duration(seconds: 10),
      backgroundColor: Colors.orange,
      content: Row(
        children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(config.body ?? ''),
              ],
            ),
          ),
          TextButton(onPressed: () => null, child: Text('test'))
        ],
      ),
    ));
  }
}

class SnackBarConfig {
  final String? title;
  final String? body;
  final SnackbarType type;

  SnackBarConfig({this.title, this.body, this.type = SnackbarType.info});
}
