/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/machine_deletion_warning.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';
import 'package:mobileraker/ui/components/supporter_ad.dart';
import 'package:mobileraker/ui/screens/dashboard/components/control_xyz/control_xyz_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/webcams/cam_card.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/general_tab_controller.dart';
import 'package:progress_indicators/progress_indicators.dart';

import '../../../components/remote_connection_active_card.dart';
import '../components/printer_info_card.dart';
import '../components/temperature_card/temperature_sensor_preset_card.dart';
import '../components/z_offset_card.dart';

class GeneralTab extends ConsumerWidget {
  const GeneralTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(generalTabViewControllerProvider.select((value) => value.when(
              data: (data) => const AsyncValue.data(true),
              error: (e, s) => AsyncValue.error(e, s),
              loading: () => const AsyncValue.loading(),
            )))
        .when(
          data: (data) {
            var printState =
                ref.watch(generalTabViewControllerProvider.select((data) => data.value!.printerData.print.state));
            var machineId = ref.watch(generalTabViewControllerProvider.select((data) => data.value!.machine.uuid));

            // return const TemperatureSensorPresetCard();

            return PullToRefreshPrinter(
              child: ListView(
                key: const PageStorageKey('gTab'),
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  const MachineDeletionWarning(),
                  const SupporterAd(),
                  RemoteConnectionActiveCard(machineId: machineId),
                  const PrintCard(),
                  TemperatureSensorPresetCard(machineUUID: machineId),
                  const CamCard(),
                  if (printState != PrintState.printing) const ControlXYZCard(),
                  if (ref.watch(settingServiceProvider).readBool(AppSettingKeys.alwaysShowBabyStepping) ||
                      const {PrintState.printing, PrintState.paused}.contains(printState))
                    ZOffsetCard(
                      machineUUID: machineId,
                    ),
                ],
              ),
            );
          },
          error: (e, s) {
            logger.e('Cought error in General tab', e, s);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(FlutterIcons.sad_cry_faw5s, size: 99),
                  const SizedBox(height: 22),
                  const Text(
                    'Error while trying to fetch printer...\nPlease provide the error to the project owner\nvia GitHub!',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => ref.read(dialogServiceProvider).show(
                          DialogRequest(
                            type: CommonDialogs.stacktrace,
                            title: e.runtimeType.toString(),
                            body: 'Exception:\n $e\n\n$s',
                          ),
                        ),
                    child: const Text('Show Error'),
                  ),
                ],
              ),
            );
          },
          loading: () => const _FetchingData(),
        );
  }
}

class _FetchingData extends StatelessWidget {
  const _FetchingData({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitRipple(
            color: Theme.of(context).colorScheme.secondary,
            size: 100,
          ),
          const SizedBox(height: 30),
          FadingText('Fetching printer data'),
        ],
      ),
    );
  }
}
