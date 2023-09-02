/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'klipper.freezed.dart';
part 'klipper.g.dart';

enum KlipperState {
  ready('klipper_state.ready', Colors.green),
  error('klipper_state.error', Colors.red),
  shutdown('klipper_state.shutdown'),
  startup('klipper_state.starting'),
  disconnected('klipper_state.disconnected'),
  unauthorized('klipper_state.unauthorized');

  const KlipperState(this.name, [this.color = Colors.orange]);

  final String name;
  final Color color;
}

@freezed
class KlipperInstance with _$KlipperInstance {
  const KlipperInstance._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory KlipperInstance(
      {@Default(false) bool klippyConnected,
      @Default(KlipperState.disconnected) KlipperState klippyState,
      @Default([]) List<String> components,
      @Default([]) List<String> registeredDirectories,
      @Default([]) List<String> warnings,
      @JsonKey(name: 'state_message') String? klippyStateMessage}) = _KlipperInstance;

  bool get hasTimelapseComponent => components.contains('timelapse');

  factory KlipperInstance.fromJson(Map<String, dynamic> json) => _$KlipperInstanceFromJson(json);

  factory KlipperInstance.partialUpdate(
          KlipperInstance current, Map<String, dynamic> partialJson) =>
      KlipperInstance.fromJson({...current.toJson(), ...partialJson});

  bool get klippyCanReceiveCommands => klippyState == KlipperState.ready && klippyConnected;
}
