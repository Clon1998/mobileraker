/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/util/extensions/klippy_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/connection/connection_state_controller.dart';
import 'package:mobileraker/ui/components/power_api_panel.dart';
import 'package:mobileraker/ui/components/simple_error_widget.dart';
import 'package:progress_indicators/progress_indicators.dart';

class KlippyStateWidget extends ConsumerWidget {
  const KlippyStateWidget({
    Key? key,
    required this.onConnected,
    this.skipKlipperReady = false,
  }) : super(key: key);
  final Widget onConnected;
  final bool skipKlipperReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (skipKlipperReady) {
      return onConnected;
    }
    if (ref.watch(printerSelectedProvider.select((value) => value.hasValue && !value.isLoading))) {
      return onConnected;
    }

    var klippy = ref.watch(klipperSelectedProvider);

    var themeData = Theme.of(context);

    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      child: klippy.when(
        skipLoadingOnRefresh: false,
        data: (data) {
          switch (data.klippyState) {
            case KlipperState.disconnected:
            case KlipperState.shutdown:
            case KlipperState.error:
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
                                  onPressed:
                                      ref.read(connectionStateControllerProvider.notifier).onRestartKlipperPressed,
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
                  if (data.components.contains('power')) const PowerApiCard(),
                ],
              );
            case KlipperState.startup:
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
                            title: Text(data.klippyState.name).tr(),
                          ),
                          const Text(
                            'components.connection_watcher.server_starting',
                          ).tr(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            case KlipperState.unauthorized:
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

            case KlipperState.ready:
            default:
              return onConnected;
          }
        },
        error: (e, s) {
          String title = 'Unable to fetch klippy data!';
          String message = e.toString();
          if (e is MobilerakerException) {
            title = e.message;
            if (e.parentException != null) {
              message = e.parentException.toString();
            }
          }

          return SimpleErrorWidget(
            title: Text(title),
            body: Text(message),
            action: TextButton.icon(
              onPressed: () {
                var machine = ref.read(selectedMachineProvider).valueOrNull;
                if (machine == null) return;
                logger.i('Invalidating klipper service provider, to retry klippy fetching');
                ref.invalidate(klipperServiceProvider(machine.uuid));
              },
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text('general.retry').tr(),
            ),
          );
        },
        loading: () => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 10),
            FadingText('Fetching Klippy Data...'),
          ],
        ),
      ),
    );
  }
}
