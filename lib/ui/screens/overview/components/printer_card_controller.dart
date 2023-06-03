import 'package:go_router/go_router.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/webcam_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/ref_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'printer_card_controller.g.dart';



@riverpod
Machine printerCardMachine(PrinterCardMachineRef ref) => throw UnimplementedError();

@Riverpod(dependencies: [goRouter, printerCardMachine, klipper, selectedMachineService])
class PrinterCardController extends _$PrinterCardController {
  SelectedMachineService get _selectedMachineService =>
      ref.read(selectedMachineServiceProvider);

  GoRouter get _goRouter => ref.read(goRouterProvider);

  Machine get machine => ref.read(printerCardMachineProvider);

  @override
  FutureOr<WebcamInfo?> build() async {
    var machine = ref.watch(printerCardMachineProvider);
    await ref.watchWhere<KlipperInstance>(klipperProvider(machine.uuid),
        (c) => c.klippyState == KlipperState.ready, false);
    var filteredCams =
        await ref.watch(filteredWebcamInfosProvider(machine.uuid).future);
    if (filteredCams.isEmpty) return null;
    return ref.watch(
        webcamInfoProvider(machine.uuid, filteredCams.first.uuid).future);
  }

  onTapTile() {
    ref.read(selectedMachineServiceProvider).selectMachine(machine);
    _goRouter.goNamed(AppRoute.dashBoard.name);
  }

  onLongPressTile() {
    _selectedMachineService.selectMachine(machine);
    _goRouter.pushNamed(AppRoute.printerEdit.name, extra: machine);
  }

  onFullScreenTap() {
    _goRouter.pushNamed(AppRoute.fullCam.name,
        extra: {'machine': machine, 'selectedCam': state.value!});
  }
}
