import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';

final gcodeProvider =
Provider.autoDispose<GCodeFile>((ref) => throw UnimplementedError());

final canStartPrintProvider = Provider.autoDispose<bool>((ref) {
  var canPrint = ref.watch(printerSelectedProvider.select((value) =>
      {
        PrintState.complete,
        PrintState.error,
        PrintState.standby
      }.contains(value.valueOrFullNull?.print.state)));

  var klippyCanReceiveCommands = ref.watch(klipperSelectedProvider.select(
          (value) => value.valueOrFullNull?.klippyCanReceiveCommands == true));

  return canPrint && klippyCanReceiveCommands;
});

final gcodeFileDetailsControllerProvider =
StateNotifierProvider.autoDispose<GCodeFileDetailsController, void>(
        (ref) => GCodeFileDetailsController(ref));

class GCodeFileDetailsController extends StateNotifier<void> {
  GCodeFileDetailsController(this.ref)
      : printerService = ref.watch(printerServiceSelectedProvider),
        dialogService = ref.watch(dialogServiceProvider),
        super(null);
  final AutoDisposeRef ref;
  final PrinterService printerService;
  final DialogService dialogService;

  onStartPrintTap() {
    printerService.startPrintFile(
        ref.read(gcodeProvider));
    ref.read(goRouterProvider).goNamed(AppRoute.dashBoard.name);
  }

  onPreHeatPrinterTap() {
    var gCodeFile = ref.read(gcodeProvider);
    dialogService.showConfirm(
      title: 'Preheat?',
      body: 'Target Temperatures\n'
          'Extruder: 170°C\n'
          'Bed: ${gCodeFile.firstLayerTempBed?.toStringAsFixed(0)}°C',
      confirmBtn: 'Preheat',

    ).then((dialogResponse) {
      if (dialogResponse?.confirmed ?? false) {
        printerService.setTemperature('extruder', 170);
        printerService.setTemperature(
            'heater_bed', (gCodeFile.firstLayerTempBed ?? 60.0).toInt());
        //TODO::
        // _snackBarService.showSnackbar(
        //     title: 'Confirmed',
        //     message:
        //     'Preheating Extruder: 170°C, Bed: ${_file.firstLayerTempBed
        //         ?.toStringAsFixed(0)}°C');
      }
    });
  }
}