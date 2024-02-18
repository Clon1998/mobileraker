/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/power_api_panel.dart';
import 'package:mobileraker/ui/components/pull_to_refresh_printer.dart';
import 'package:mobileraker/ui/screens/dashboard/components/bed_mesh_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/control_extruder_card.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';
import 'package:progress_indicators/progress_indicators.dart';

import '../../../components/horizontal_scroll_indicator.dart';
import '../components/fans_card.dart';
import '../components/firmware_retraction_card.dart';
import '../components/limits_card.dart';
import '../components/multipliers_card.dart';
import '../components/pins_card.dart';

class ControlTab extends ConsumerWidget {
  const ControlTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var settingService = ref.watch(settingServiceProvider);

    return ref.watch(machinePrinterKlippySettingsProvider.selectAs((data) => data.machine.uuid)).when(
          data: (data) {
            var groupSliders = settingService.readBool(AppSettingKeys.groupSliders, true);
            return PullToRefreshPrinter(
              child: ListView(
                key: const PageStorageKey<String>('cTab'),
                padding: const EdgeInsets.only(bottom: 30),
                children: [
                  ControlExtruderCard(machineUUID: data),
                  FansCard(machineUUID: data),
                  PinsCard(machineUUID: data),
                  if (ref
                          .watch(machinePrinterKlippySettingsProvider
                              .selectAs((value) => value.klippyData.components.contains('power')))
                          .valueOrNull ??
                      false)
                    const PowerApiCard(),
                  if (groupSliders) const _MiscCard(),
                  if (!groupSliders) ...[
                    MultipliersCard(machineUUID: data),
                    LimitsCard(machineUUID: data),
                    if (ref
                            .watch(machinePrinterKlippySettingsProvider
                                .selectAs((data) => data.printerData.firmwareRetraction != null))
                            .valueOrNull ==
                        true)
                      FirmwareRetractionCard(machineUUID: data),
                  ],
                  BedMeshCard(machineUUID: data),
                ],
              ),
            );
          },
          error: (e, s) {
            logger.e('Cought error in Controller tab', e, s);
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
                    // onPressed: model.showPrinterFetchingErrorDialog,
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
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SpinKitRipple(
                  color: Theme.of(context).colorScheme.secondary,
                  size: 100,
                ),
                const SizedBox(height: 30),
                FadingText('Fetching printer data'),
                // Text('Fetching printer ...')
              ],
            ),
          ),
        );
  }
}

class _MiscCard extends HookConsumerWidget {
  const _MiscCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pageController = usePageController();

    var macineUUID = ref.watch(machinePrinterKlippySettingsProvider.selectAs((data) => data.machine.uuid)).value!;
    var childs = [
      MultipliersSlidersOrTexts(machineUUID: macineUUID),
      LimitsSlidersOrTexts(machineUUID: macineUUID),
      if (ref
              .watch(machinePrinterKlippySettingsProvider.selectAs(
                (data) => data.printerData.firmwareRetraction != null,
              ))
              .valueOrNull ==
          true)
        FirmwareRetractionSlidersOrTexts(machineUUID: macineUUID),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Column(
          children: [
            ExpandablePageView(
              key: const PageStorageKey<String>('sliders_and_text'),
              estimatedPageSize: 250,
              controller: pageController,
              children: childs,
            ),
            HorizontalScrollIndicator(
              steps: childs.length,
              controller: pageController,
              childsPerScreen: 1,
            ),
          ],
        ),
      ),
    );
  }
}
