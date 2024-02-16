/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/setting_service.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'full_cam_controller.g.dart';

@Riverpod(dependencies: [])
Machine fullCamMachine(FullCamMachineRef ref) => throw UnimplementedError();

@Riverpod(dependencies: [])
WebcamInfo initialCam(InitialCamRef ref) => throw UnimplementedError();

@Riverpod(dependencies: [fullCamMachine, initialCam, settingService])
class FullCamPageController extends _$FullCamPageController {
  @override
  WebcamInfo build() {
    var rotateCam = ref.watch(settingServiceProvider).readBool(AppSettingKeys.fullscreenCamOrientation, false);
    if (rotateCam) {
      SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
    }

    ref.onDispose(() {
      if (rotateCam) {
        SystemChrome.setPreferredOrientations([]);
      }
    });

    return ref.watch(initialCamProvider);
  }

  selectCam(WebcamInfo? cam) {
    if (cam == null) return;
    state = cam;
  }
}
