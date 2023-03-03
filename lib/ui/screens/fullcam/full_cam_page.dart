import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/ui/components/interactive_viewer_center.dart';
import 'package:mobileraker/ui/components/mjpeg.dart';
import 'package:mobileraker/ui/components/octo_widgets.dart';
import 'package:mobileraker/ui/screens/fullcam/full_cam_controller.dart';
import 'package:stringr/stringr.dart';

class FullCamPage extends ConsumerWidget {
  final Machine machine;
  final int initialCam;

  const FullCamPage(this.machine, this.initialCam, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(selectedCamIndexProvider.notifier).state = initialCam;
    return ProviderScope(
      overrides: [
        camMachineProvider.overrideWithValue(machine),
      ],
      child: const _FullCamView(),
    );
  }
}

class _FullCamView extends ConsumerWidget {
  const _FullCamView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(camMachineProvider);
    var clientType = ref.watch(jrpcClientTypeProvider(machine.uuid));
    var index = ref.watch(selectedCamIndexProvider);
    var selectedCam = machine.cams[index];

    Uri camUri = Uri.parse(selectedCam.url);
    Map<String, String> headers = {};
    if (clientType == ClientType.octo) {
      Uri machineUri = Uri.parse(machine.wsUrl);
      if (machineUri.host == camUri.host) {
        var octoEverywhere = machine.octoEverywhere!;

        camUri = camUri.replace(scheme: 'https', host: octoEverywhere.uri.host);

        headers[HttpHeaders.authorizationHeader] =
            octoEverywhere.basicAuthorizationHeader;
        ;
      }
    }

    return Scaffold(
      body: Stack(alignment: Alignment.center, children: [
        CenterInteractiveViewer(
            constrained: true,
            minScale: 1,
            maxScale: 10,
            child: Mjpeg(
              key: ValueKey(selectedCam.url),
              config: MjpegConfig(
                  feedUri: camUri.toString(),
                  httpHeader: headers,
                  targetFps: selectedCam.targetFps,
                  mode: selectedCam.mode),
              showFps: true,
              transform: selectedCam.transformMatrix,
              stackChild: const [StackContent()],
            )),
        if (machine.cams.length > 1)
          Align(
            alignment: Alignment.bottomCenter,
            child: DropdownButton<int>(
                value: index,
                onChanged: (s) =>
                    ref.read(selectedCamIndexProvider.notifier).state = s!,
                items: machine.cams.mapIndex((e, i) {
                  return DropdownMenuItem(
                    value: i,
                    child: Text(e.name),
                  );
                }).toList()),
          ),
        Align(
          alignment: Alignment.bottomRight,
          child: IconButton(
            icon: const Icon(Icons.close_fullscreen_outlined),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        if (clientType != ClientType.local)
          const Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: OctoIndicator(),
            ),
          ),
      ]),
    );
  }
}

class StackContent extends ConsumerWidget {
  const StackContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(camMachineProvider);
    var printer = ref.watch(printerProvider(machine.uuid));

    return Positioned.fill(
      child: Stack(
        children: printer.maybeWhen(
            orElse: () => [],
            data: (d) {
              var extruder = d.extruder;
              var target = extruder.target;

              var nozzleText =
                  tr('pages.dashboard.general.temp_preset_card.h_temp', args: [
                '${extruder.temperature.toStringAsFixed(1)}${target > 0 ? '/${target.toStringAsFixed(1)}' : ''}'
              ]);
              var bedTarget = d.heaterBed.target;
              var bedText =
                  tr('pages.dashboard.general.temp_preset_card.b_temp', args: [
                '${d.heaterBed.temperature.toStringAsFixed(1)}${bedTarget > 0 ? '/${bedTarget.toStringAsFixed(1)}' : ''}'
              ]);

              return [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                        margin: const EdgeInsets.only(top: 5, left: 2),
                        child: Text(
                          '$nozzleText\n$bedText',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                        )),
                  ),
                ),
                if (d.print.state == PrintState.printing)
                  Positioned.fill(
                    child: Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(
                          value: d.virtualSdCard.progress,
                        )),
                  )
              ];
            }),
      ),
    );
  }
}
