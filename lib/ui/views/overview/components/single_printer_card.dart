import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/data/datasource/json_rpc_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/components/mjpeg.dart';
import 'package:mobileraker/ui/views/overview/components/single_printer_card_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';

class SinglePrinterCard extends ViewModelBuilderWidget<SinglePrinterCardViewModel> {
  final Machine _machine;

  SinglePrinterCard(this._machine);

  @override
  Widget builder(
      BuildContext context, SinglePrinterCardViewModel model, Widget? child) {
    return Card(
      child: Column(
        children: [
          if (model.selectedCam != null)
            Center(
                child: Mjpeg(
              key: ValueKey(model.selectedCam!.uuid),
              feedUri: model.selectedCam!.url,
              targetFps: model.selectedCam!.targetFps,
              transform: model.selectedCam!.transformMatrix,
              camMode: model.selectedCam!.mode,
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

  Widget? _buildTrailing(BuildContext context, SinglePrinterCardViewModel model) {
    if (!model.isWebsocketStateAvailable) return FadingText('...');

    if (model.clientState != ClientState.connected)
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
  SinglePrinterCardViewModel viewModelBuilder(BuildContext context) =>
      SinglePrinterCardViewModel(_machine);
}
