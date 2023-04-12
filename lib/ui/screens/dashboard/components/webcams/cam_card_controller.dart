import 'dart:async';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
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
    required WebcamInfo activeCam,
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
    var filteredCams =
        await ref.watch(filteredWebcamInfosProvider(machine.uuid).future);
    var selIndex = min(
        filteredCams.length - 1,
        max(
            0,
            ref
                .read(settingServiceProvider)
                .readInt(selectedWebcamGrpIndex, 0)));
    var activeCam = await ref.watch(
        webcamInfoProvider(machine.uuid, filteredCams[selIndex].uuid).future);

    return CamCardState(
        allCams: filteredCams,
        activeCam: activeCam,
        clientType: ref.watch(jrpcClientTypeProvider(machine.uuid)),
        machine: machine);
  }

  onSelectedChange(String? camUUID) async {
    if (camUUID == null ||
        !state.hasValue ||
        state.value?.activeCam.uuid == camUUID) return;

    var c = await ref
        .watch(webcamInfoProvider(state.value!.machine.uuid, camUUID).future);

    var indexOf = state.value!.allCams.indexOf(c);
    ref.read(settingServiceProvider).writeInt(selectedWebcamGrpIndex, indexOf);
    state = AsyncValue.data(state.value!.copyWith(activeCam: c));
  }

  onFullScreenTap() {
    Machine machine = ref.read(selectedMachineProvider).value!;
    ref.read(goRouterProvider).pushNamed(AppRoute.fullCam.name,
        extra: {'machine': machine, 'selectedCam': state.value!.activeCam});
  }

  onRetry() {
    if (state.hasValue) {
      ref.invalidate(webcamInfoProvider(
          state.value!.machine.uuid, state.value!.activeCam.uuid));
    }
  }
}
