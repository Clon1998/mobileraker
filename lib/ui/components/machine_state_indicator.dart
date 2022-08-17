import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/ui/theme/theme_pack.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';

class MachineStateIndicator extends ConsumerWidget {
  const MachineStateIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    KlipperInstance? klippyData = ref.watch(klipperSelectedProvider).valueOrFullNull;

    KlipperState serverState = klippyData?.klippyState ?? KlipperState.disconnected;

    return Tooltip(
      padding: const EdgeInsets.all(8.0),
      message: 'pages.dashboard.server_status'.tr(args: [
        serverState.name.tr(),
        klippyData?.klippyConnected ?? false
            ? tr('general.connected').toLowerCase()
            : tr('klipper_state.disconnected').toLowerCase()
      ], gender: 'available'),
      child: Icon(Icons.radio_button_on,
          size: 10, color: _stateToColor(context, serverState)),
    );
  }

  Color _stateToColor(BuildContext context, KlipperState state) {
    CustomColors? customColors = Theme.of(context).extension<CustomColors>();

    switch (state) {
      case KlipperState.ready:
        return customColors?.success ?? Colors.green;
      case KlipperState.error:
        return customColors?.danger ?? Colors.red;
      case KlipperState.startup:
        return customColors?.info ?? Colors.blueAccent;
      case KlipperState.shutdown:
      case KlipperState.disconnected:
      default:
        return customColors?.warning ?? Colors.orange;
    }
  }
}
