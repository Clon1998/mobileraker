import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/power/power_device.dart';
import 'package:mobileraker/data/dto/power/power_state.dart';
import 'package:mobileraker/service/moonraker/power_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/ui/components/adaptive_horizontal_scroll.dart';
import 'package:mobileraker/ui/components/card_with_switch.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/misc.dart';

class PowerApiCard extends ConsumerWidget {
  const PowerApiCard({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {


    var powerDevicesLen = ref.watch(powerDevicesSelectedProvider.selectAs(
        (data) =>
            data.where((element) => !element.name.startsWith('_')).length));
    return powerDevicesLen.maybeWhen(
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
                      children: List.generate(data, (index) {
                        var powerDeviceProvider =
                            powerDevicesSelectedProvider.selectAs((data) => data
                                .where(
                                    (element) => !element.name.startsWith('_'))
                                .elementAt(index));

                        return _PowerDeviceCard(
                            powerDeviceProvider: powerDeviceProvider);
                      }),
                    )
                  ],
                ),
              ),
            ),
        orElse: () => const SizedBox.shrink());
  }
}

class _PowerDeviceCard extends ConsumerWidget {
  const _PowerDeviceCard({Key? key, required this.powerDeviceProvider})
      : super(key: key);

  final ProviderListenable<AsyncValue<PowerDevice>> powerDeviceProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var powerDevice = ref.watch(powerDeviceProvider).valueOrFullNull!;
    return CardWithSwitch(
        value: powerDevice.status == PowerState.on,
        onChanged: (powerDevice.lockedWhilePrinting &&
                    ref.watch(printerSelectedProvider.select((d) =>
                        d.valueOrFullNull?.print.state ==
                        PrintState.printing)) ||
                powerDevice.status == PowerState.init)
            ? null
            : (d) => ref.read(powerServiceSelectedProvider).setDeviceStatus(
                powerDevice.name, d ? PowerState.on : PowerState.off),
        child: Builder(builder: (context) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(beautifyName(powerDevice.name),
                  style: Theme.of(context).textTheme.caption),
              Text(powerDevice.status.name.capitalize,
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          );
        }));
  }
}
