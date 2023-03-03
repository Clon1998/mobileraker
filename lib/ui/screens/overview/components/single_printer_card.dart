import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/wrapper/riverpod_machine_wrapper.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/components/mjpeg.dart';
import 'package:mobileraker/ui/screens/overview/components/single_printer_card_viewmodel.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:progress_indicators/progress_indicators.dart';

class SinglePrinterCard extends ConsumerWidget {
  SinglePrinterCard(
    this._machine, {
    Key? key,
  }) : super(key: key) {
    _machineWrapper = MachineWrapper(_machine);
  }

  final Machine _machine;
  late final MachineWrapper _machineWrapper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var webcamSetting =
        ref.watch(singlePrinterCardControllerProvider(_machineWrapper));
    var singlePrinterCardController = ref
        .watch(singlePrinterCardControllerProvider(_machineWrapper).notifier);
    var printState = ref
        .watch(printerProvider(_machine.uuid).selectAs((d) => d.print.state))
        .valueOrFullNull;

    return Card(
      child: Column(
        children: [
          if (webcamSetting != null)
            Center(
                child: Mjpeg(
              key: ValueKey(webcamSetting.uuid),
              transform: webcamSetting.transformMatrix,
              config: MjpegConfig(
                  feedUri: webcamSetting.url,
                  targetFps: webcamSetting.targetFps,
                  mode: webcamSetting.mode),
              imageBuilder: _imageBuilder,
              stackChild: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.aspect_ratio),
                      tooltip:
                          tr('pages.dashboard.general.cam_card.fullscreen'),
                      onPressed: singlePrinterCardController.onFullScreenTap,
                    ),
                  ),
                ),
                if (printState == PrintState.printing)
                  _PrintProgressBar(_machine)
              ],
            )),
          ListTile(
            onTap: singlePrinterCardController.onTapTile,
            onLongPress: singlePrinterCardController.onLongPressTile,
            title: Text(_machine.name),
            subtitle: Text(_machine.httpUrl),
            trailing: _Trailing(_machine),
          )
        ],
      ),
    );
  }

  Widget _imageBuilder(BuildContext context, Widget imageTransformed) {
    return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        child: imageTransformed);
  }
}

class _Trailing extends ConsumerWidget {
  const _Trailing(
    this._machine, {
    Key? key,
  }) : super(key: key);
  final Machine _machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(jrpcClientStateProvider(_machine.uuid)).when(
          data: (d) {
            if (d != ClientState.connected) {
              return Icon(
                FlutterIcons.disconnect_ant,
                size: 20,
                color: Theme.of(context).errorColor,
              );
            }
            return MachineStateIndicator(_machine);
          },
          error: (e, s) => Tooltip(
                message: e.toString(),
                child: Icon(
                  FlutterIcons.disconnect_ant,
                  size: 20,
                  color: Theme.of(context).errorColor,
                ),
              ),
          loading: () => FadingText('...'));
}

class _PrintProgressBar extends ConsumerWidget {
  const _PrintProgressBar(
    this._machine, {
    Key? key,
  }) : super(key: key);
  final Machine _machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned.fill(
      child: Align(
          alignment: Alignment.bottomCenter,
          child: LinearProgressIndicator(
            value: ref
                    .watch(printerProvider(_machine.uuid)
                        .selectAs((data) => data.virtualSdCard.progress))
                    .valueOrFullNull ??
                0,
          )),
    );
  }
}
