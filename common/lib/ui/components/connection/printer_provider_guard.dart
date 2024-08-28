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

import '../responsive_limit.dart';

/// A widget that guards the provided child widget with a printer provider.
/// It listens to the printer provider state and displays an error widget if an error occurs.
class PrinterProviderGuard extends ConsumerWidget {
  const PrinterProviderGuard({
    super.key,
    required this.machineUUID,
    required this.child,
  });

  final String machineUUID;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (hasError, error) = ref.watch(printerProvider(machineUUID).select((it) => (it is AsyncError, it.error)));

    logger.i('PrinterProviderGuard($machineUUID): hasError: $hasError, error: $error');

    if (hasError) {
      return _ProviderError(key: const Key('ppErr'), machineUUID: machineUUID, error: error!);
    }

    return child;
  }
}

class _ProviderError extends ConsumerWidget {
  const _ProviderError({super.key, required this.machineUUID, required this.error});

  final String machineUUID;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.w('Showing PrinterProviderGuard.error for $machineUUID: $error');

    String title = 'Error while fetching Printer Data';
    String message = error.toString();
    var e = error;
    if (e is MobilerakerException) {
      // title = e.message;
      if (e.parentException != null) {
        message = e.parentException.toString();
      }
    }

    return ResponsiveLimit(
      child: Padding(
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
      ),
    );
  }
}
