/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:math';

import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/webcam_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cam_card_controller.freezed.dart';
part 'cam_card_controller.g.dart';

@freezed
class CamCardState with _$CamCardState {
  const factory CamCardState({
    required List<WebcamInfo> allCams,
    required WebcamInfo? activeCam,
    required ClientType clientType,
    required Machine machine,
  }) = _CamCardState;
}

@riverpod
class CamCardController extends _$CamCardController {
  @override
  FutureOr<CamCardState> build() async {
    var aliveLink = ref.keepAlive();
    Timer? timer;
    ref.onCancel(() {
      // start a 30 second timer
      timer = Timer(const Duration(seconds: 30), () {
        // dispose on timeout
        aliveLink.close();
      });
    });
    // If the provider is listened again after it was paused, cancel the timer
    ref.onResume(() {
      timer?.cancel();
    });
    ref.onDispose(() => timer?.cancel);

    Machine machine = (await ref.watch(selectedMachineProvider.future))!;
    var filteredCams = await ref.watch(allSupportedWebcamInfosProvider(machine.uuid).future);

    WebcamInfo? activeCam;
    if (filteredCams.isNotEmpty) {
      var selIndex = min(filteredCams.length - 1,
          max(0, ref.read(settingServiceProvider).readInt(UtilityKeys.webcamIndex, 0)));
      activeCam = filteredCams[selIndex];
    }

    return CamCardState(
        allCams: filteredCams,
        activeCam: activeCam,
        clientType: ref.watch(jrpcClientTypeProvider(machine.uuid)),
        machine: machine);
  }

  onSelectedChange(String? camUUID) async {
    if (camUUID == null || !state.hasValue || state.value?.activeCam?.uuid == camUUID) return;

    var cams = state.value!.allCams;
    var indexOf = cams.indexWhere((cam) => cam.uuid == camUUID);
    ref.read(settingServiceProvider).writeInt(UtilityKeys.webcamIndex, indexOf);
    state = AsyncValue.data(state.value!.copyWith(activeCam: cams[indexOf]));
  }

  onFullScreenTap() {
    Machine machine = ref.read(selectedMachineProvider).value!;
    ref.read(goRouterProvider).pushNamed(AppRoute.fullCam.name,
        extra: {'machine': machine, 'selectedCam': state.value!.activeCam});
  }

  onRetry() {
    if (state.hasValue && state.value!.activeCam != null) {
      ref.invalidate(allWebcamInfosProvider(state.value!.machine.uuid));
    }
  }
}
