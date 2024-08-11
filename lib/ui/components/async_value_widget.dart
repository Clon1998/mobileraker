/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.skipLoadingOnRefresh = false,
    this.skipLoadingOnReload = false,
    this.skipError = false,
    this.debugLabel,
  });

  // input async value
  final AsyncValue<T> value;

  // output builder function
  final Widget Function(T) data;
  final Widget Function()? loading;
  final Widget Function(Object error, StackTrace stackTrace)? error;

  final bool skipLoadingOnRefresh;
  final bool skipLoadingOnReload;
  final bool skipError;

  /// An optional label for debugging purposes.
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    if (debugLabel != null) {
      logger.i(
          'Rebuilding AsyncValueWidget: $debugLabel with ${value.isLoading ? '(isRefresh: ${value.isRefreshing}, isReload: ${value.isReloading}, initialLoading: ${!value.isRefreshing && !value.isReloading}) ' : ''}$value');
    }

    return value.when(
      skipLoadingOnRefresh: this.skipLoadingOnRefresh,
      skipLoadingOnReload: this.skipLoadingOnReload,
      skipError: this.skipError,
      data: data,
      loading: loading ?? () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, s) {
        if (error != null) {
          return error!(e, s);
        }
        logger.e('Error in Widget', e, s);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FlutterIcons.bug_faw5s, size: 99),
              const SizedBox(height: 22),
              Text('Error:\n$e', textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}
