import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/power/power_device.dart';
import 'package:mobileraker/data/dto/power/power_state.dart';
import 'package:mobileraker/service/moonraker/power_service.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/card_with_switch.dart';
import 'package:mobileraker/util/misc.dart';

class PowerApiCard extends ConsumerWidget {
  const PowerApiCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var powerDevices = ref.watch(powerDevicesSelectedProvider);

    return powerDevices.maybeWhen(
        data: (data) => Card(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    FlutterIcons.power_fea,
                  ),
                  title:
                  const Text('pages.dashboard.control.power_card.title')
                      .tr(),
                ),
                AdaptiveHorizontalScroll(
                  pageStorageKey: 'powers',
                  children: List.generate(data.length, (index) {
                    PowerDevice powerDevice = data[index];

                    return CardWithSwitch(
                        value: powerDevice.status == PowerState.on,
                        onChanged: (d) => ref
                            .read(powerServiceSelectedProvider)
                            .setDeviceStatus(powerDevice.name,
                            d ? PowerState.on : PowerState.off),
                        child: Builder(builder: (context) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(beautifyName(powerDevice.name),
                                  style:
                                  Theme.of(context).textTheme.caption),
                              Text(
                                  powerDevice.status == PowerState.on
                                      ? 'general.on'.tr()
                                      : 'general.off'.tr(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall),
                            ],
                          );
                        }));
                  }),
                )
              ],
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink());
  }
}