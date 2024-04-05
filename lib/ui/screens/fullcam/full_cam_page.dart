/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/connection/client_type_indicator.dart';
import 'package:mobileraker/ui/components/webcam/webcam.dart';
import 'package:mobileraker/ui/screens/fullcam/full_cam_controller.dart';

class FullCamPage extends ConsumerWidget {
  final Machine machine;
  final WebcamInfo initialCam;

  const FullCamPage(this.machine, this.initialCam, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        fullCamMachineProvider.overrideWithValue(machine),
        initialCamProvider.overrideWithValue(initialCam),
        // fullCamPageControllerProvider,
      ],
      child: const _FullCamView(),
    );
  }
}

class _FullCamView extends ConsumerWidget {
  const _FullCamView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(fullCamMachineProvider);
    var clientType = ref.watch(jrpcClientTypeProvider(machine.uuid));
    var selectedCam = ref.watch(fullCamPageControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          InteractiveViewer(
            constrained: true,
            maxScale: 10,
            child: SizedBox.expand(
              child: Center(
                child: Webcam(
                  machine: machine,
                  webcamInfo: selectedCam,
                  stackContent: const [StackContent()],
                  showFpsIfAvailable: true,
                  showRemoteIndicator: false,
                ),
              ),
            ),
          ),
          const _CamSelector(),
          Align(
            alignment: Alignment.bottomRight,
            child: IconButton(
              icon: const Icon(Icons.close_fullscreen_outlined),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: MachineActiveClientTypeIndicator(
                machineId: machine.uuid,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class StackContent extends ConsumerWidget {
  const StackContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(fullCamMachineProvider);
    var printer = ref.watch(printerProvider(machine.uuid));

    var numFormat = NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);

    return Positioned.fill(
      child: Stack(
        children: printer.maybeWhen(
          orElse: () => [],
          data: (d) {
            var extruder = d.extruder;
            var target = extruder.target;

            var nozzleText = tr('pages.dashboard.general.temp_preset_card.h_temp', args: [
              '${numFormat.format(extruder.temperature)}${target > 0 ? '/${numFormat.format(target)}' : ''}',
            ]);
            String info = nozzleText;

            if (d.heaterBed != null) {
              var bedTarget = d.heaterBed!.target;
              var bedText = tr(
                'pages.dashboard.general.temp_preset_card.b_temp',
                args: [
                  '${numFormat.format(d.heaterBed!.temperature)}${bedTarget > 0 ? '/${numFormat.format(bedTarget)}' : ''}',
                ],
              );
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              if (d.print.state == PrintState.printing)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: LinearProgressIndicator(
                      value: d.printProgress,
                    ),
                  ),
                ),
            ];
          },
        ),
      ),
    );
  }
}

class _CamSelector extends ConsumerWidget {
  const _CamSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machine = ref.watch(fullCamMachineProvider);

    var webcams = ref.watch(allSupportedWebcamInfosProvider(machine.uuid)).valueOrNull ?? [];

    if (webcams.length <= 1) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: DropdownButton<WebcamInfo>(
        value: ref.watch(fullCamPageControllerProvider),
        onChanged: ref.watch(fullCamPageControllerProvider.notifier).selectCam,
        items: webcams
            .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(beautifyName(c.name)),
                ))
            .toList(),
      ),
    );
  }
}
