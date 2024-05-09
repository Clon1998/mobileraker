/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/horizontal_scroll_indicator.dart';
import 'package:mobileraker_pro/service/ui/dashboard_layout_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../dashboard_card.dart';

part 'dashboard_layout_sheet.g.dart';

class DashboardLayoutBottomSheet extends HookConsumerWidget {
  const DashboardLayoutBottomSheet({super.key, required this.machineUUID, required this.currentLayout});

  final String machineUUID;

  final DashboardLayout currentLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_dashboardLayoutControllerProvider(currentLayout).notifier);

    return ProviderScope(
      child: DraggableScrollableSheet(
        expand: false,
        maxChildSize: 1,
        initialChildSize: 0.35,
        minChildSize: 0.35,
        builder: (ctx, scrollController) {
          var themeData = Theme.of(ctx);

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: SafeArea(
              // This is for tablets for now...
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min, // To make the card compact
                  children: [
                    Text(
                      'Dashboard Layout',
                      style: themeData.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Current Layout: ${currentLayout.name}',
                      style: themeData.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: exportLayout,
                                child: const AutoSizeText('Export', maxLines: 1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: controller.onImportLayout,
                                child: const AutoSizeText('Import', maxLines: 1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    Text('Available Layouts:', style: themeData.textTheme.labelLarge),
                    Expanded(
                      child: AsyncGuard(
                        toGuard: _dashboardLayoutControllerProvider(currentLayout).selectAs((_) => true),
                        childOnData: _AvailableLayouts(
                          scrollController: scrollController,
                          currentLayout: currentLayout,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void exportLayout() {
    var json = currentLayout.export();
    var str = jsonEncode(json);
    // Copy to clipboard

    Share.share(str, subject: 'Dashboard Layout');
  }
}

class _AvailableLayouts extends ConsumerWidget {
  const _AvailableLayouts({super.key, required this.scrollController, required this.currentLayout});

  final ScrollController scrollController;
  final DashboardLayout currentLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableLayouts = ref.watch(_dashboardLayoutControllerProvider(currentLayout)).requireValue;
    final controller = ref.watch(_dashboardLayoutControllerProvider(currentLayout).notifier);

    var theme = Theme.of(context);

    return CustomScrollView(
      // shrinkWrap: true,
      controller: scrollController,
      slivers: [
        SliverList.list(
          children: [
            for (var layout in availableLayouts)
              _LayoutPreview(
                layout: layout,
                isCurrent: layout.uuid == currentLayout.uuid,
                onTapLoad: controller.onLayoutSelected,
                onTapDelete: (_) => null,
                onTapReset: controller.onResetLayout,
              ),
          ],
        ),
        if (availableLayouts.isEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Center(
                child: Text('No Layouts available', style: theme.textTheme.bodySmall),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: ElevatedButton.icon(
            onPressed: controller.onAddEmptyLayout,
            icon: const Icon(Icons.add),
            label: const Text('Add Empty Layout'),
          ),
        ),
      ],
    );
  }
}

class _LayoutPreview extends HookWidget {
  const _LayoutPreview({
    super.key,
    required this.layout,
    required this.isCurrent,
    required this.onTapLoad,
    required this.onTapDelete,
    required this.onTapReset,
  });

  final DashboardLayout layout;
  final bool isCurrent;
  final void Function(DashboardLayout layout) onTapLoad;
  final void Function(DashboardLayout layout) onTapDelete;
  final void Function(DashboardLayout layout) onTapReset;
  static const int _pagesOnScreen = 3;

  @override
  Widget build(BuildContext context) {
    final controller = useScrollController();

    final width = MediaQuery.maybeSizeOf(context)?.width ?? 300;
    final scollSteps = layout.tabs.length / _pagesOnScreen;
    final themeData = Theme.of(context);

    // FilledButton(
    //   onPressed: () => onTapLoad(layout),
    //   style: FilledButton.styleFrom(
    //     foregroundColor: themeData.extension<CustomColors>()?.onDanger,
    //     backgroundColor: themeData.extension<CustomColors>()?.danger,
    //   ),
    //   child: const Text('Delete'),
    // ),
    // const SizedBox(width: 8),
    // FilledButton(onPressed: () => onTapLoad(layout), child: const Text('Load')),

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(layout.name, style: themeData.textTheme.titleMedium),
                    const Spacer(),
                    if (isCurrent)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('Current', style: TextStyle(color: themeData.colorScheme.onPrimary)),
                        backgroundColor: themeData.colorScheme.primary,
                      ),
                  ],
                ),
                const Divider(),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final scrollWidth = constraints.maxWidth;
                    return SingleChildScrollView(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var tab in layout.tabs)
                            Builder(builder: (ctx) {
                              return ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: scrollWidth / _pagesOnScreen),
                                child: FittedBox(
                                  child: SizedBox(
                                    width: width,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var card in tab.components) DasboardCard.preview(type: card.type),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                ),
                if (scollSteps > 1) ...[
                  const SizedBox(height: 4),
                  HorizontalScrollIndicator(
                    dots: (scollSteps).ceil(),
                    controller: controller,
                    decorator: DotsDecorator(
                      activeColor: themeData.colorScheme.primary,
                      size: const Size(6, 6),
                      activeSize: const Size(6, 6),
                      spacing: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Row(
                children: [
                  //TODO: Add management of layouts
                  // ElevatedButton.icon(
                  //   onPressed: () => onTapLoad(layout),
                  //   style: ElevatedButton.styleFrom(
                  //     // elevation: 2,
                  //     foregroundColor: themeData.extension<CustomColors>()?.onDanger,
                  //     backgroundColor: themeData.extension<CustomColors>()?.danger,
                  //     visualDensity: VisualDensity.compact,
                  //     textStyle: themeData.textTheme.bodySmall,
                  //   ),
                  //   icon: const Icon(Icons.delete_forever, size: 18),
                  //   label: const Text('Delete'),
                  // ),
                  // const SizedBox(width: 8),
                  if (isCurrent)
                    ElevatedButton.icon(
                      onPressed: () => onTapReset(layout),
                      style: ElevatedButton.styleFrom(
                        // elevation: 2,
                        visualDensity: VisualDensity.compact,
                        textStyle: themeData.textTheme.bodySmall,
                        foregroundColor: themeData.colorScheme.onSecondary,
                        backgroundColor: themeData.colorScheme.secondary,
                      ),
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Reset'),
                    ),
                  if (!isCurrent)
                    ElevatedButton.icon(
                      onPressed: () => onTapLoad(layout),
                      style: ElevatedButton.styleFrom(
                        // elevation: 2,
                        visualDensity: VisualDensity.compact,
                        textStyle: themeData.textTheme.bodySmall,
                      ),
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Load'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@riverpod
class _DashboardLayoutController extends _$DashboardLayoutController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  DashboardLayoutService get _dashboardService => ref.read(dashboardLayoutServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  @override
  Future<List<DashboardLayout>> build(DashboardLayout layout) async {
    final availableLayouts = [...await _dashboardService.availableLayouts()];

    // Add the current layout to the list, if it is not already there
    if (!availableLayouts.any((element) => element.uuid == layout.uuid)) {
      availableLayouts.add(layout);
    }

    return availableLayouts;
  }

  void onResetLayout(DashboardLayout layout) {
    final defaultDashboardLayout = _dashboardService.defaultDashboardLayout();

    // Transfer the UUID to the default to reset the layout
    defaultDashboardLayout
      ..name = layout.name
      ..uuid = layout.uuid
      ..created = layout.created
      ..lastModified = layout.lastModified;

    onLayoutSelected(defaultDashboardLayout);
  }

  void onLayoutSelected(DashboardLayout layout) {
    _goRouter.pop(BottomSheetResult.confirmed(layout));
  }

  void onAddEmptyLayout() {
    final layout = _dashboardService.emptyDashboardLayout();
    onLayoutSelected(layout);
  }

  Future<void> onImportLayout() async {
    try {
      var data = await Clipboard.getData('text/plain');
      final json = jsonDecode(data!.text!);

      final layout = ref.read(dashboardLayoutServiceProvider).importFromJson(json);

      onLayoutSelected(layout);
      _snackBarService.show(SnackBarConfig(
        title: 'Layout imported',
        message: 'Remember to save the layout',
        duration: const Duration(seconds: 5),
      ));
    } catch (e, s) {
      logger.e('Error importing layout: $e');
      _snackBarService.show(SnackBarConfig.stacktraceDialog(
        dialogService: _dialogService,
        exception: e,
        stack: s,
        snackTitle: 'Error importing layout',
      ));
    }
  }
}
