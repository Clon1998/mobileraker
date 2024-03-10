/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/util/extensions/klippy_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/connection/connection_state_controller.dart';
import 'package:mobileraker/ui/components/power_api_card.dart';

import 'connection_state_view.dart';

class KlippyStateWidget extends HookConsumerWidget {
  const KlippyStateWidget({
    super.key,
    required this.machineUUID,
    required this.onConnected,
    this.skipKlipperReady = false,
  });

  final String machineUUID;
  final OnConnectedBuilder onConnected;
  final bool skipKlipperReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If we had a AsyncData previously, the dashboard should take care of showing KLIPPY errors
    var fetchedOnce = useRef(false);

    var klippy = ref.watch(klipperProvider(machineUUID));
    // logger.w('Models(hasErr: ${klippy.hasError}): $klippy');

    var wasFetched = fetchedOnce.value;
    if (klippy case AsyncData(value: KlipperInstance(klippyState: KlipperState.ready))) {
      fetchedOnce.value = true;
    }

    return AnimatedSwitcher(
      // duration: Duration(milliseconds: 2200),
      duration: kThemeAnimationDuration,
      child: switch (klippy) {
        AsyncData(
          value: KlipperInstance(
                klippyState: KlipperState.error || KlipperState.disconnected || KlipperState.shutdown
              ) &&
              final kInstance
          // The `when !wasFetched` ensures to skip the state error if we had a AsyncData before -> the dashboard should take care of showing errors
        )
            when !skipKlipperReady && !wasFetched =>
          _StateError(data: kInstance, machineUUID: machineUUID),
        AsyncData(value: KlipperInstance(klippyState: KlipperState.unauthorized)) => const _StateUnauthorized(),
        AsyncError(:final error) => _ProviderError(machineUUID: machineUUID, error: error),
        _ => onConnected(context, machineUUID),
      },
    );
  }
}

class _StateError extends ConsumerWidget {
  const _StateError({super.key, required this.data, required this.machineUUID});

  final KlipperInstance data;
  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(FlutterIcons.disconnect_ant),
                  title: Text('Klippy: @:${data.klippyState.name}').tr(),
                ),
                Text(
                  data.statusMessage,
                  style: TextStyle(color: themeData.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                ElevatedButtonTheme(
                  data: ElevatedButtonThemeData(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeData.colorScheme.error,
                      foregroundColor: themeData.colorScheme.onError,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: ref.read(connectionStateControllerProvider.notifier).onRestartKlipperPressed,
                        child: const Text(
                          'pages.dashboard.general.restart_klipper',
                        ).tr(),
                      ),
                      ElevatedButton(
                        onPressed: ref.read(connectionStateControllerProvider.notifier).onRestartMCUPressed,
                        child: const Text(
                          'pages.dashboard.general.restart_mcu',
                        ).tr(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (data.hasPowerComponent) PowerApiCard(machineUUID: machineUUID),
      ],
    );
  }
}

class _StateUnauthorized extends ConsumerWidget {
  const _StateUnauthorized({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.gpp_bad, size: 70),
        const SizedBox(height: 30),
        const Text(
          'It seems like you configured trusted clients for Moonraker. Please add the API key in the printers settings!\n',
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: ref.read(connectionStateControllerProvider.notifier).onEditPrinter,
          child: Text('components.nav_drawer.printer_settings'.tr()),
        ),
      ],
    );
  }
}

class _ProviderError extends ConsumerWidget {
  const _ProviderError({super.key, required this.machineUUID, required this.error});

  final String machineUUID;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title = 'Error while fetching Klipper Data';
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
            logger.i('Invalidating klipper service provider, to retry klippy fetching');
            ref.invalidate(klipperServiceProvider(machineUUID));
          },
          icon: const Icon(Icons.restart_alt_outlined),
          label: const Text('general.retry').tr(),
        ),
      ),
    );
  }
}
