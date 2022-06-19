
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/datasource/json_rpc_client.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class SinglePrinterCardViewModel extends MultipleStreamViewModel {
  static const String PrinterKey = 'printer';
  static const String ServerKey = 'server';
  static const String ClientStateKey = 'clientState';
  final _selectedMachineService = locator<SelectedMachineService>();
  final _navigationService = locator<NavigationService>();
  final Machine _machine;

  SinglePrinterCardViewModel(this._machine);

  @override
  Map<String, StreamData> get streamsMap => {
    PrinterKey: StreamData<Printer>(_machine.printerService.printerStream),
    ServerKey:
    StreamData<KlipperInstance>(_machine.klippyService.klipperStream),
    ClientStateKey:
    StreamData<ClientState>(_machine.jRpcClient.stateStream),
  };

  Printer? get printer => dataMap?[PrinterKey];

  bool get isPrinterAvailable => dataReady(PrinterKey);

  KlipperInstance? get server => dataMap![ServerKey];

  bool get isServerAvailable => dataReady(ServerKey);

  ClientState? get clientState => dataMap![ClientStateKey];

  bool get isWebsocketStateAvailable => dataReady(ClientStateKey);

  WebcamSetting? selectedCam;

  bool get showProgress => printer?.print.state == PrintState.printing;

  double get printProgress => printer?.virtualSdCard.progress ?? 0;

  String get wsError => _machine.jRpcClient.hasError
      ? _machine.jRpcClient.errorReason.toString()
      : 'Unknown';

  onTapTile() {
    _selectedMachineService.selectMachine(_machine);
    _navigationService.navigateTo(Routes.dashboardView);
  }

  onLongPressTile() {
    _selectedMachineService.selectMachine(_machine);
    _navigationService.navigateTo(Routes.printerEdit,
        arguments: PrinterEditArguments(machine: _machine));
  }

  onFullScreenTap() {
    _navigationService.navigateTo(Routes.fullCamView,
        arguments:
        FullCamViewArguments(webcamSetting: selectedCam!, owner: _machine));
  }

  @override
  initialise() {
    super.initialise();

    List<WebcamSetting> tmpCams = _machine.cams;
    if (tmpCams.isNotEmpty) selectedCam = tmpCams.first;
    _machine.jRpcClient.ensureConnection();
  }
}
