/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/moonraker/webcam_service.dart';
import 'package:mobileraker/ui/components/interactive_viewer_center.dart';
import 'package:mobileraker/ui/components/octo_widgets.dart';
import 'package:mobileraker/ui/components/webcam/webcam.dart';
import 'package:mobileraker/ui/screens/fullcam/full_cam_controller.dart';
import 'package:mobileraker/util/misc.dart';

class FullCamPage extends ConsumerWidget {
  final Machine machine;
  final WebcamInfo initialCam;

  const FullCamPage(this.machine, this.initialCam, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        fullCamMachineProvider.overrideWithValue(machine),
        initialCamProvider.overrideWithValue(initialCam),
        fullCamPageControllerProvider
      ],
      child: const _FullCamView(),
    );
  }
}

class _FullCamView extends ConsumerWidget {
  const _FullCamView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(fullCamMachineProvider);
    var clientType = ref.watch(jrpcClientTypeProvider(machine.uuid));
    var selectedCam = ref.watch(fullCamPageControllerProvider);

    return Scaffold(
      body: Stack(alignment: Alignment.center, children: [
        CenterInteractiveViewer(
            constrained: true,
            minScale: 1,
            maxScale: 10,
            child: Webcam(
              machine: machine,
              webcamInfo: selectedCam,
              stackContent: const [StackContent()],
              showFpsIfAvailable: true,
              showRemoteIndicator: false,
            )),
        const _CamSelector(),
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
    var machine = ref.watch(fullCamMachineProvider);
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
              String info = nozzleText;

              if (d.heaterBed != null) {
                var bedTarget = d.heaterBed!.target;
                var bedText = tr(
                    'pages.dashboard.general.temp_preset_card.b_temp',
                    args: [
                      '${d.heaterBed!.temperature.toStringAsFixed(1)}${bedTarget > 0 ? '/${bedTarget.toStringAsFixed(1)}' : ''}'
                    ]);
                info = '$info\n$bedText';
              }

              return [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                        margin: const EdgeInsets.only(top: 5, left: 2),
                        child: Text(
                          info,
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

class _CamSelector extends ConsumerWidget {
  const _CamSelector({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(fullCamMachineProvider);

    var webcams =
        ref.watch(filteredWebcamInfosProvider(machine.uuid)).valueOrNull ?? [];

    if (webcams.length <= 1) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: DropdownButton<WebcamInfo>(
          value: ref.watch(fullCamPageControllerProvider),
          onChanged:
              ref.watch(fullCamPageControllerProvider.notifier).selectCam,
          items: webcams
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(beautifyName(c.name)),
                  ))
              .toList()),
    );
  }
}
