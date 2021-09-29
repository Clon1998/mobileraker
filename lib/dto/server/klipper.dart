import 'package:flutter/material.dart';

enum KlipperState { ready, error, shutdown, startup, disconnected }

class KlipperInstance {
  bool klippyConnected;

  KlipperState klippyState; //Matches Printer state
  String get klippyStateName => printerStateName(klippyState);

  List<String> plugins;

  KlipperInstance(
      {this.klippyConnected = false,
      this.klippyState = KlipperState.error,
      this.plugins = const []});

  String get stateName => printerStateName(klippyState);

  static Color stateToColor(KlipperState state) {
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

  static String printerStateName(KlipperState printerState) {
    switch (printerState) {
      case KlipperState.ready:
        return "Ready";
      case KlipperState.shutdown:
        return "Shutdown";
      case KlipperState.startup:
        return "Starting";
      case KlipperState.disconnected:
        return "Disconnected";
      case KlipperState.error:
      default:
        return "Error";
    }
  }

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
