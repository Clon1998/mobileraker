/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../components/horizontal_scroll_indicator.dart';
import 'firmware_retraction_card.dart';
import 'limits_card.dart';
import 'multipliers_card.dart';

class GroupedSlidersCard extends HookConsumerWidget {
  const GroupedSlidersCard({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    var pageController = usePageController();

    var showFwRetract =
        ref.watch(printerProvider(machineUUID).selectAs((data) => data.firmwareRetraction != null)).valueOrNull == true;

    var childs = [
      MultipliersSlidersOrTexts(machineUUID: machineUUID),
      LimitsSlidersOrTexts(machineUUID: machineUUID),
      if (showFwRetract) FirmwareRetractionSlidersOrTexts(machineUUID: machineUUID),
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
