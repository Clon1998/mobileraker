import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

enum KlipperState { ready, error, shutdown, startup, disconnected }

String toName(KlipperState printerState) {
  switch (printerState) {
    case KlipperState.ready:
      return tr('klipper_state.ready');
    case KlipperState.shutdown:
      return tr('klipper_state.shutdown');
    case KlipperState.startup:
      return tr('klipper_state.starting');
    case KlipperState.disconnected:
      return tr('klipper_state.disconnected');
    case KlipperState.error:
    default:
      return tr('klipper_state.error');
  }
}

Color stateToColor(KlipperState state) {
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

class KlipperInstance {
  bool klippyConnected;

  KlipperState klippyState; //Matches Printer state

  List<String> plugins;

  String? klippyStateMessage;

  KlipperInstance(
      {this.klippyConnected = false,
      this.klippyState = KlipperState.error,
      this.plugins = const []});

  @override
  String toString() {
    return 'KlipperInstance{klippyConnected: $klippyConnected, klippyState: $klippyState, plugins: $plugins}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KlipperInstance &&
          runtimeType == other.runtimeType &&
          klippyConnected == other.klippyConnected &&
          klippyState == other.klippyState &&
          plugins == other.plugins;

  @override
  int get hashCode =>
      klippyConnected.hashCode ^ klippyState.hashCode ^ plugins.hashCode;
}
