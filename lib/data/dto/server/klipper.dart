import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'klipper.freezed.dart';

enum KlipperState {
  ready('klipper_state.ready', Colors.green),
  error('klipper_state.error', Colors.red),
  shutdown('klipper_state.shutdown'),
  startup('klipper_state.starting'),
  disconnected('klipper_state.disconnected');

  const KlipperState(this.name, [this.color = Colors.orange]);

  final String name;
  final Color color;
}

@freezed
class KlipperInstance with _$KlipperInstance {
  const KlipperInstance._();
  const factory KlipperInstance(
      {@Default(false) bool klippyConnected,
      @Default(KlipperState.error) KlipperState klippyState,
      @Default([]) List<String> plugins,
      String? klippyStateMessage}) = _KlipperInstance;

  bool get klippyCanReceiveCommands =>
      klippyState == KlipperState.ready &&
          klippyConnected;
}
