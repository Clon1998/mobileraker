import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/dto/server/klipper.dart';

class MachineStateIndicator extends StatelessWidget {
  final KlipperInstance? server;

  const MachineStateIndicator(this.server, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      padding: EdgeInsets.all(8.0),
      child: Icon(Icons.radio_button_on,
          size: 10, color: _stateToColor(server?.klippyState)),

      message: 'pages.dashboard.server_status'.tr(args: [
        _isServerAvailable ? toName(server!.klippyState) : '',
        _isServerAvailable && server!.klippyConnected
            ? tr('general.connected').toLowerCase()
            : tr('klipper_state.disconnected').toLowerCase()
      ], gender: _isServerAvailable ? 'available' : 'unavailable'),
    );
  }

  bool get _isServerAvailable => server != null;

  Color _stateToColor(KlipperState? state) {
    state = state ?? KlipperState.error;
    switch (state) {
      case KlipperState.ready:
        return Colors.green;
      case KlipperState.error:
        return Colors.red;
      case KlipperState.shutdown:
      case KlipperState.startup:
      case KlipperState.disconnected:
      default:
        return Colors.orange;
    }
  }
}
