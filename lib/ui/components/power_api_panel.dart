/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/power/power_device.dart';
import 'package:common/data/enums/power_state_enum.dart';
import 'package:common/service/moonraker/power_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/card_with_switch.dart';

class PowerApiCard extends ConsumerWidget {
  const PowerApiCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var powerDevicesLen = ref.watch(powerDevicesSelectedProvider.selectAs(
      (data) => data.where((element) => !element.name.startsWith('_')).length,
    ));
    return powerDevicesLen.maybeWhen(
      data: (data) => (data == 0)
          ? const SizedBox.shrink()
          : Card(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(FlutterIcons.power_fea),
                      title: const Text(
                        'pages.dashboard.control.power_card.title',
                      ).tr(),
                    ),
                    AdaptiveHorizontalScroll(
                      pageStorageKey: 'powers',
                      children: List.generate(data, (index) {
                        var powerDeviceProvider = powerDevicesSelectedProvider.selectAs(
                            (data) => data.where((element) => !element.name.startsWith('_')).elementAt(index));

                        return _PowerDeviceCard(
                    powerDeviceProvider: powerDeviceProvider,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _PowerDeviceCard extends ConsumerWidget {
  const _PowerDeviceCard({Key? key, required this.powerDeviceProvider}) : super(key: key);

  final ProviderListenable<AsyncValue<PowerDevice>> powerDeviceProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var powerDevice = ref.watch(powerDeviceProvider).requireValue;
    return CardWithSwitch(
      value: powerDevice.status == PowerState.on,
      onChanged: (powerDevice.status == PowerState.error ||
              powerDevice.status == PowerState.unknown ||
              powerDevice.lockedWhilePrinting &&
                  ref.watch(printerSelectedProvider.select((d) => d.valueOrNull?.print.state == PrintState.printing)) ||
              powerDevice.status == PowerState.init)
          ? null
          : (d) => ref.read(powerServiceSelectedProvider).setDeviceStatus(
                powerDevice.name,
                d ? PowerState.on : PowerState.off,
              ),
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              beautifyName(powerDevice.name),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              powerDevice.status.name.capitalize,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        );
      },
    );
  }
}
