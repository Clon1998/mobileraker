/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/logger.dart';
// Generic AsyncValueWidget to work with values of type T
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget(
      {Key? key,
      required this.value,
      required this.data,
      this.loading,
      this.skipLoadingOnRefresh = false,
      this.skipLoadingOnReload = false})
      : super(key: key);

  // input async value
  final AsyncValue<T> value;

  // output builder function
  final Widget Function(T) data;
  final Widget Function()? loading;

  final bool skipLoadingOnRefresh;
  final bool skipLoadingOnReload;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: this.skipLoadingOnRefresh,
      skipLoadingOnReload: this.skipLoadingOnReload,
      data: data,
      loading: loading ?? () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, s) {
        logger.e('Error in Widget', e, s);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FlutterIcons.bug_faw5s, size: 99),
              const SizedBox(
                height: 22,
              ),
              Text(
                'Error:\n$e',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
