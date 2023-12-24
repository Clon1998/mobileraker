/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'printer_card_controller.g.dart';

@Riverpod(dependencies: [])
Machine printerCardMachine(PrinterCardMachineRef ref) => throw UnimplementedError();

@Riverpod(dependencies: [
  goRouter,
  printerCardMachine,
  klipper,
  selectedMachineService,
])
class PrinterCardController extends _$PrinterCardController {
  SelectedMachineService get _selectedMachineService => ref.read(selectedMachineServiceProvider);

  GoRouter get _goRouter => ref.read(goRouterProvider);

  Machine get _machine => ref.read(printerCardMachineProvider);

  @override
  Stream<WebcamInfo?> build() async* {
    var machine = ref.watch(printerCardMachineProvider);
    var klipperState = await ref.watch(
      klipperProvider(machine.uuid).selectAsync((data) => data.klippyState),
    );

    if (klipperState != KlipperState.ready) return;

    var filteredCamsFuture = ref.watch(allSupportedWebcamInfosProvider(machine.uuid).future);
    if (!ref.watch(isSupporterProvider)) {
      filteredCamsFuture = filteredCamsFuture
          .then((value) => value.where((element) => !element.service.forSupporters).toList(growable: false));
    }

    var filteredCams = await filteredCamsFuture;
    yield filteredCams.firstOrNull;
  }

  onTapTile() {
    ref.read(selectedMachineServiceProvider).selectMachine(_machine);
    _goRouter.goNamed(AppRoute.dashBoard.name);
  }

  onLongPressTile() {
    _selectedMachineService.selectMachine(_machine);
    _goRouter.pushNamed(AppRoute.printerEdit.name, extra: _machine);
  }

  onFullScreenTap() {
    _goRouter.pushNamed(
      AppRoute.fullCam.name,
      extra: {'machine': _machine, 'selectedCam': state.value!},
    );
  }
}
