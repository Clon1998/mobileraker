/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// This widget watches the ASYNCVALUE (AsyncError) of the printerProvider and handles the error state of the provider to prevent any issues down the widget tree
class PrinterProviderGuard extends HookConsumerWidget {
  const PrinterProviderGuard({
    super.key,
    required this.machineUUID,
    required this.child,
  });

  final String machineUUID;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var printer = ref.watch(printerProvider(machineUUID));

    // logger.i('Rebuilding PrinterProviderGuard ');

    return switch (printer) {
      AsyncError(:final error) => _ProviderError(key: const Key('ppErr'), machineUUID: machineUUID, error: error),
      _ => child,
    };

    // return AnimatedSwitcher(
    //   // duration: Duration(milliseconds: 2200),
    //   duration: kThemeAnimationDuration,
    //   child: switch (printer) {
    //     AsyncError(:final error) => _ProviderError(key: const Key('ppErr'), error: error),
    //     _ => child,
    //   },
    // );
  }
}

class _ProviderError extends ConsumerWidget {
  const _ProviderError({super.key, required this.machineUUID, required this.error});

  final String machineUUID;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title = 'Error while fetching Printer Data';
    String message = error.toString();
    var e = error;
    if (e is MobilerakerException) {
      // title = e.message;
      if (e.parentException != null) {
        message = e.parentException.toString();
      }
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SimpleErrorWidget(
        title: Text(title),
        body: Text(message),
        action: TextButton.icon(
          onPressed: () {
            logger.i('Invalidating printer service provider, to retry printer fetching');
            ref.invalidate(printerServiceProvider(machineUUID));
          },
          icon: const Icon(Icons.restart_alt_outlined),
          label: const Text('general.retry').tr(),
        ),
      ),
    );
  }
}
