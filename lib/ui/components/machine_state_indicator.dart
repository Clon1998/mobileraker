import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/ui/themes/theme_pack.dart';

class MachineStateIndicator extends StatelessWidget {
  final KlipperInstance? server;

  const MachineStateIndicator(this.server, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      padding: EdgeInsets.all(8.0),
      child: Icon(Icons.radio_button_on,
          size: 10, color: _stateToColor(context, server?.klippyState)),
      message: 'pages.dashboard.server_status'.tr(args: [
        _isServerAvailable ? toName(server!.klippyState) : '',
        _isServerAvailable && server!.klippyConnected
            ? tr('general.connected').toLowerCase()
            : tr('klipper_state.disconnected').toLowerCase()
      ], gender: _isServerAvailable ? 'available' : 'unavailable'),
    );
  }

  bool get _isServerAvailable => server != null;

  Color _stateToColor(BuildContext context, KlipperState? state) {
    CustomColors? customColors = Theme.of(context).extension<CustomColors>();

    state = state ?? KlipperState.error;
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
