import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';
import 'package:mobileraker/data/wrapper/riverpod_machine_wrapper.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/selected_machine_service.dart';

final singlePrinterCardControllerProvider = StateNotifierProvider.autoDispose
    .family<SinglePrinterCardController, WebcamSetting?, MachineWrapper>(
        (ref, machine) {
  return SinglePrinterCardController(ref, machine.machine);
}, name: 'singlePrinterCardControllerProvider');

class SinglePrinterCardController extends StateNotifier<WebcamSetting?> {
  SinglePrinterCardController(AutoDisposeRef ref, this._machine)
      : _selectedMachineService = ref.watch(selectedMachineServiceProvider),
        _goRouter = ref.watch(goRouterProvider),
        super(null) {
    logger.w(
        'CREATED SinglePrinterCardController ${_machine.hashCode} #${identityHashCode(this)}');

    ref.read(jrpcClientProvider(_machine.uuid)).ensureConnection();
    List<WebcamSetting> tmpCams = _machine.cams;
    if (tmpCams.isNotEmpty) state = tmpCams.first;
  }

  final Machine _machine;
  final SelectedMachineService _selectedMachineService;
  final GoRouter _goRouter;

  onTapTile() {
    _selectedMachineService.selectMachine(_machine);
    _goRouter.goNamed(AppRoute.dashBoard.name);
  }

  onLongPressTile() {
    _selectedMachineService.selectMachine(_machine);
    _goRouter.pushNamed(AppRoute.printerEdit.name, extra: _machine);
  }

  onFullScreenTap() {
    _goRouter.pushNamed(AppRoute.fullCam.name, extra: {
      'machine': _machine,
      'selectedCam': _machine.cams.indexOf(state!)
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SinglePrinterCardController &&
          runtimeType == other.runtimeType &&
          _machine == other._machine &&
          state == other.state;

  @override
  int get hashCode => state.hashCode ^ _machine.hashCode;
}
