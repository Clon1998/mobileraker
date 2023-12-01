/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../routing/app_router.dart';

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
  String _keySuffix = '';

  KeyValueStoreKey get _webcamIndexKey => CompositeKey.keyWithString(UtilityKeys.webcamIndex, _keySuffix);

  @override
  FutureOr<CamCardState> build() async {
    ref.keepAliveFor();
    Machine machine = (await ref.watch(selectedMachineProvider.future))!;
    var filteredCams = await ref.watch(allSupportedWebcamInfosProvider(machine.uuid).future);
    _keySuffix = machine.uuid;

    WebcamInfo? activeCam;
    if (filteredCams.isNotEmpty) {
      var selIndex = min(
        filteredCams.length - 1,
        max(0, ref.read(settingServiceProvider).readInt(_webcamIndexKey, 0)),
      );
      activeCam = filteredCams.elementAtOrNull(selIndex);
    }

    return CamCardState(
      allCams: filteredCams,
      activeCam: activeCam,
      clientType: ref.watch(jrpcClientTypeProvider(machine.uuid)),
      machine: machine,
    );
  }

  onSelectedChange(String? camUUID) {
    if (camUUID == null || !state.hasValue || state.value?.activeCam?.uuid == camUUID) return;

    var cams = state.value!.allCams;
    var indexOf = cams.indexWhere((cam) => cam.uuid == camUUID);
    ref.read(settingServiceProvider).writeInt(_webcamIndexKey, indexOf);
    state = AsyncValue.data(state.value!.copyWith(activeCam: cams[indexOf]));
  }

  onFullScreenTap() {
    Machine machine = ref.read(selectedMachineProvider).value!;
    ref.read(goRouterProvider).pushNamed(
      AppRoute.fullCam.name,
      extra: {'machine': machine, 'selectedCam': state.value!.activeCam},
    );
  }

  onRetry() {
    if (state.hasValue && state.value!.activeCam != null) {
      ref.invalidate(allWebcamInfosProvider(state.value!.machine.uuid));
    }
  }
}
