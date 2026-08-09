/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../network/jrpc_client_provider.dart';
import '../../util/extensions/ref_extension.dart';
import '../misc_providers.dart';

part 'webcam_beacon_service.g.dart';

/// Keeps a Snapmaker U1's onboard camera stream alive.
///
/// The U1 stops streaming unless it periodically receives a `camera.start_monitor`
/// call over the already-authenticated Moonraker websocket. This controller is only
/// meant to be watched while a webcam flagged via `WebcamInfo.requiresU1Beacon` is
/// actually being displayed, and only sends the beacon while the app is foregrounded.
@riverpod
class U1CameraBeaconController extends _$U1CameraBeaconController {
  static const _interval = Duration(seconds: 10);

  Timer? _timer;

  @override
  void build(String machineUUID) {
    ref.keepAliveFor();

    ref.listen(
      appLifecycleProvider,
      (_, appState) {
        switch (appState) {
          case AppLifecycleState.resumed:
            _start();
          case AppLifecycleState.paused:
            _stop();
          default:
          // Do nothing
        }
      },
      fireImmediately: true,
    );

    ref.onCancel(_stop);
    ref.onResume(_start);
    ref.onDispose(_stop);
  }

  void _start() {
    _stop();
    _sendBeacon();
    _timer = Timer.periodic(_interval, (_) => _sendBeacon());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sendBeacon() async {
    final client = ref.read(jrpcClientProvider(machineUUID));
    client.sendJRpcMethod('camera.start_monitor', params: {'domain': 'lan', 'interval': 0}).ignore();
  }
}
