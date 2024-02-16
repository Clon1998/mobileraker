/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dialog_service_interface.dart';

part 'snackbar_service_interface.g.dart';

enum SnackbarType { error, warning, info }

class SnackBarConfig {
  final SnackbarType type;
  final Duration? duration;
  final String? title;
  final String? message;
  final String? mainButtonTitle;
  final VoidCallback? onMainButtonTapped;
  final bool closeOnMainButtonTapped;

  SnackBarConfig(
      {this.type = SnackbarType.info,
      this.duration = const Duration(seconds: 5),
      this.title,
      this.message,
      this.mainButtonTitle,
      this.onMainButtonTapped,
      this.closeOnMainButtonTapped = false});

  factory SnackBarConfig.stacktraceDialog({
    required DialogService dialogService,
    required Object exception,
    required StackTrace stack,
    String snackTitle = 'Error',
    String? snackMessage,
    String? dialogTitle,
    String? dialogExceptionPrefix,
  }) {
    return SnackBarConfig(
        type: SnackbarType.error,
        title: snackTitle,
        message: snackMessage ?? exception.toString(),
        duration: const Duration(seconds: 30),
        mainButtonTitle: tr('general.details'),
        closeOnMainButtonTapped: true,
        onMainButtonTapped: () {
          var prefix = (dialogExceptionPrefix != null) ? '$dialogExceptionPrefix\n' : '';

          dialogService.show(DialogRequest(
              type: CommonDialogs.stacktrace,
              title: dialogTitle ?? snackTitle,
              body: '${prefix}Exception:\n $exception\n\n$stack'));
        });
  }
}

@Riverpod(keepAlive: true)
SnackBarService snackBarService(SnackBarServiceRef ref) => throw UnimplementedError();

abstract interface class SnackBarService {
  show(SnackBarConfig config);
}
