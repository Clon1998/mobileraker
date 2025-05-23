/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/overview/components/common/state_chips.dart';

import '../../../../../routing/app_router.dart';
import '../../../../components/machine_state_indicator.dart';
import '../../../../components/webcam/webcam.dart';

class MachineCamBaseCard extends ConsumerWidget {
  const MachineCamBaseCard({super.key, required this.machine, required this.body});

  final Machine machine;

  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    talker.info('Rebuilding MachineCamBaseCard for ${machine.logName}');

    final themeData = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(machine: machine),
          Divider(height: 0),
          Flexible(child: _Cam(machine: machine)),
          Padding(padding: const EdgeInsets.all(8.0), child: body),
          if (themeData.useMaterial3) Gap(4),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final clientState = ref.watch(jrpcClientStateProvider(machine.uuid).requireValue());

    talker.info('Rebuilding _Header for ${machine.logName}');

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          MachineStateIndicator(machine),
          Gap(8),
          Expanded(child: Text(machine.name, style: themeData.textTheme.titleMedium)),
          ClientStateChip(state: clientState),
        ],
      ),
    );
  }
}

class _Cam extends ConsumerWidget {
  const _Cam({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //TODO: Decide if I want a loading animation here or if it is fine to load it after the JRPC State widget
    final previewCam = ref.watch(activeWebcamInfoForMachineProvider(machine.uuid)).value;
    if (previewCam == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Webcam(
            webcamInfo: previewCam,
            machine: machine,
            showRemoteIndicator: false,
            stackContent: [
              Consumer(builder: (innerContext, innerRef, _) {
                final innerThemeData = Theme.of(innerContext);
                final printState =
                    innerRef.watch(printerProvider(machine.uuid).selectAs((d) => d.print.state)).valueOrNull;
                if (printState == null) return const SizedBox.shrink();
                return Positioned.fill(
                  top: innerThemeData.useMaterial3 ? 4 : 0,
                  left: 8,
                  child: Align(alignment: Alignment.topLeft, child: PrintStateChip(printState: printState)),
                );
              }),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.aspect_ratio),
                    tooltip: tr('pages.dashboard.general.cam_card.fullscreen'),
                    onPressed: () {
                      final goRouter = ref.read(goRouterProvider);
                      goRouter.pushNamed(
                        AppRoute.fullCam.name,
                        extra: {'machine': machine, 'selectedCam': previewCam},
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 0),
        ],
      ),
    );
  }
}
