import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/datasource/websocket_wrapper.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/components/mjpeg.dart';
import 'package:mobileraker/ui/views/overview/overview_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import '../../../domain/webcam_setting.dart';

class OverViewView extends ViewModelBuilderWidget<OverViewViewModel> {
  const OverViewView({Key? key}) : super(key: key);

  @override
  Widget builder(
          BuildContext context, OverViewViewModel model, Widget? child) =>
      Scaffold(
        appBar: AppBar(
          title: Text(
            'pages.overview.title',
            overflow: TextOverflow.fade,
          ).tr(),
        ),
        body: _buildBody(context, model),
        drawer: NavigationDrawerWidget(curPath: Routes.overViewView),
      );

  Widget _buildBody(BuildContext context, OverViewViewModel model) {
    if (!model.dataReady) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitRipple(
            color: Theme.of(context).colorScheme.primary,
            size: 100,
          ),
          SizedBox(
            height: 30,
          ),
          FadingText(tr('pages.overview.fetching_machines')),
          // Text('Fetching printer ...')
        ],
      ));
    }

    List<PrinterSetting> machines = model.data!;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...machines.map((machine) => SinglePrinter(machine)),
          Center(
            child: ElevatedButton.icon(
                onPressed: model.onAddPressed,
                icon: Icon(Icons.add),
                label: Text('pages.overview.add_machine').tr()),
          )
        ],
      ),
    );
  }

  @override
  OverViewViewModel viewModelBuilder(BuildContext context) =>
      OverViewViewModel();
}

class SinglePrinter extends ViewModelBuilderWidget<SinglePrinterViewModel> {
  final PrinterSetting _machine;

  SinglePrinter(this._machine);

  @override
  Widget builder(
      BuildContext context, SinglePrinterViewModel model, Widget? child) {
    return Card(
      child: Column(
        children: [
          if (model.selectedCam != null)
            Center(
                child: Mjpeg(
              key: ValueKey(model.selectedCam!.uuid),
              feedUri: model.selectedCam!.url,
              transform: model.selectedCam!.transformMatrix,
              imageBuilder: _imageBuilder,
              stackChildren: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: IconButton(
                      color: Colors.white,
                      icon: Icon(Icons.aspect_ratio),
                      tooltip:
                          tr('pages.dashboard.general.cam_card.fullscreen'),
                      onPressed: model.onFullScreenTap,
                    ),
                  ),
                ),
                if (model.showProgress)
                  Positioned.fill(
                    child: Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(
                          value: model.printProgress,
                        )),
                  )
              ],
            )),
          ListTile(
            onTap: model.onTapTile,
            onLongPress: model.onLongPressTile,
            title: Text(_machine.name),
            subtitle: Text(_machine.httpUrl),
            trailing: _buildTrailing(context, model),
          )
        ],
      ),
    );
  }

  Widget? _buildTrailing(BuildContext context, SinglePrinterViewModel model) {
    if (!model.isWebsocketStateAvailable) return FadingText('...');

    if (model.websocketState != WebSocketState.connected)
      return Tooltip(
        child: Icon(
          FlutterIcons.disconnect_ant,
          size: 20,
          color: Theme.of(context).errorColor,
        ),
        message: model.wsError,
      );

    return MachineStateIndicator(
      model.server,
    );
  }

  Widget _imageBuilder(BuildContext context, Transform imageTransformed) {
    return ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
        child: imageTransformed);
  }

  @override
  SinglePrinterViewModel viewModelBuilder(BuildContext context) =>
      SinglePrinterViewModel(_machine);
}

class SinglePrinterViewModel extends MultipleStreamViewModel {
  static const String PrinterKey = 'printer';
  static const String ServerKey = 'server';
  static const String WsKey = 'websocketState';
  final _machineService = locator<MachineService>();
  final _navigationService = locator<NavigationService>();
  final PrinterSetting _machine;

  SinglePrinterViewModel(this._machine);

  @override
  Map<String, StreamData> get streamsMap => {
        PrinterKey: StreamData<Printer>(_machine.printerService.printerStream),
        ServerKey:
            StreamData<KlipperInstance>(_machine.klippyService.klipperStream),
        WsKey: StreamData<WebSocketState>(_machine.websocket.stateStream),
      };

  Printer? get printer => dataMap?[PrinterKey];

  bool get isPrinterAvailable => dataReady(PrinterKey);

  KlipperInstance? get server => dataMap![ServerKey];

  bool get isServerAvailable => dataReady(ServerKey);

  WebSocketState? get websocketState => dataMap![WsKey];

  bool get isWebsocketStateAvailable => dataReady(WsKey);

  WebcamSetting? selectedCam;

  bool get showProgress => printer?.print.state == PrintState.printing;

  double get printProgress => printer?.virtualSdCard.progress ?? 0;

  String get wsError => _machine.websocket.hasError
      ? _machine.websocket.errorReason.toString()
      : 'Unknown';

  void onTapTile() {
    _machineService.setMachineActive(_machine);
    _navigationService.navigateTo(Routes.dashboardView);
  }

  void onLongPressTile() {
    _machineService.setMachineActive(_machine);
    _navigationService.navigateTo(Routes.printersEdit,
        arguments: PrintersEditArguments(printerSetting: _machine));
  }

  void onFullScreenTap() {
    _navigationService.navigateTo(Routes.fullCamView,
        arguments:
            FullCamViewArguments(webcamSetting: selectedCam!, owner: _machine));
  }

  @override
  void initialise() {
    super.initialise();

    List<WebcamSetting> tmpCams = _machine.cams;
    if (tmpCams.isNotEmpty) selectedCam = tmpCams.first;
    _machine.websocket.ensureConnection();
  }
}
