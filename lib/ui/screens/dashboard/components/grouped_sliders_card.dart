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

  static Widget preview() {
    return const _Preview();
  }

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();

    var showFwRetract =
        ref.watch(printerProvider(machineUUID).selectAs((data) => data.firmwareRetraction != null)).valueOrNull == true;

    var childs = [
      MultipliersSlidersOrTexts(machineUUID: machineUUID),
      LimitsSlidersOrTexts(machineUUID: machineUUID),
      if (showFwRetract) FirmwareRetractionSlidersOrTexts(machineUUID: machineUUID),
    ];

    return _Body(childs: childs);
  }
}

class _Body extends HookWidget {
  const _Body({super.key, required this.childs});

  final List<Widget> childs;

  @override
  Widget build(BuildContext context) {
    var pageController = usePageController();

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
              dots: childs.length,
              controller: pageController,
              childsPerScreen: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends HookWidget {
  static const String _machineUUID = 'preview';

  const _Preview({super.key});

  @override
  Widget build(BuildContext context) {
    useAutomaticKeepAlive();

    return _Body(childs: [
      MultipliersSlidersOrTexts.preview(),
      LimitsSlidersOrTexts.preview(),
      FirmwareRetractionSlidersOrTexts.preview(),
    ]);
  }
}
