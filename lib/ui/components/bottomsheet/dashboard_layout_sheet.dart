/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';
import 'dart:math';

import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/logger.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/horizontal_scroll_indicator.dart';
import 'package:mobileraker_pro/service/ui/dashboard_layout_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../dashboard_card.dart';

part 'dashboard_layout_sheet.g.dart';

class DashboardLayoutBottomSheet extends HookConsumerWidget {
  const DashboardLayoutBottomSheet({super.key, required this.machineUUID, required this.currentLayout});

  final String machineUUID;

  final DashboardLayout currentLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_dashboardLayoutControllerProvider(currentLayout).notifier);
    var themeData = Theme.of(context);

    final title = PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            visualDensity: VisualDensity.compact,
            titleAlignment: ListTileTitleAlignment.center,
            title: Text('bottom_sheets.dashboard_layout.title', style: themeData.textTheme.titleLarge).tr(),
            subtitle: Text.rich(
              TextSpan(
                text: '${tr('bottom_sheets.dashboard_layout.subtitle')} ',
                children: [
                  TextSpan(
                    text: currentLayout.name,
                    // recognizer: TapGestureRecognizer()..onTap = () => controller.onRenameLayout(currentLayout),
                    style: TextStyle(color: themeData.colorScheme.primary, decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 0),
        ],
      ),
    );

    final bottom = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              onPressed: controller.onImportLayout,
              icon: Icon(FlutterIcons.database_import_mco),
              tooltip: tr('general.import'),
            ),
            Gap(8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: controller.onAddEmptyLayout,
                icon: const Icon(Icons.add),
                label: const Text('bottom_sheets.dashboard_layout.available_layouts.add_empty').tr(),
              ),
            ),
          ],
        ),
      ),
    );

    return ProviderScope(
      child: SheetContentScaffold(
        topBar: title,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap(8),
              Text(
                'bottom_sheets.dashboard_layout.available_layouts.label',
                style: themeData.textTheme.labelLarge,
              ).tr(),
              Expanded(
                child: AsyncGuard(
                  debugLabel: 'Available Layouts-list',
                  toGuard: _dashboardLayoutControllerProvider(currentLayout).selectAs((d) => true),
                  childOnData: _AvailableLayouts(currentLayout: currentLayout),
                ),
              ),
            ],
          ),
        ),
        bottomBarVisibility: BottomBarVisibility.always(),
        bottomBar: bottom,
      ),
    );
  }
}

class _AvailableLayouts extends ConsumerWidget {
  const _AvailableLayouts({super.key, required this.currentLayout});

  final DashboardLayout currentLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var aa = ref.watch(_dashboardLayoutControllerProvider(currentLayout));
    final availableLayouts = aa.requireValue;
    final controller = ref.watch(_dashboardLayoutControllerProvider(currentLayout).notifier);

    var theme = Theme.of(context);

    return CustomScrollView(
      shrinkWrap: true,
      slivers: [
        SliverList.list(
          children: [
            for (var layout in availableLayouts)
              _LayoutPreview(
                layout: layout,
                isCurrent: layout.uuid == currentLayout.uuid,
                onTapLoad: controller.onLayoutSelected,
                onTapDelete: (l) => controller.onDeleteLayout(l),
              ),
          ],
        ),
        if (availableLayouts.isEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Center(
                child: Text(
                  'bottom_sheets.dashboard_layout.available_layouts.empty',
                  style: theme.textTheme.bodySmall,
                ).tr(),
              ),
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
  });

  final DashboardLayout layout;
  final bool isCurrent;
  final void Function(DashboardLayout layout) onTapLoad;
  final void Function(DashboardLayout layout) onTapDelete;
  static const int _pagesOnScreenCompact = 3;
  static const int _pagesOnScreenMedium = 2;

  @override
  Widget build(BuildContext context) {
    final controller = useScrollController();

    final int pagesOnScreen = context.isLargerThanCompact ? _pagesOnScreenMedium : _pagesOnScreenCompact;

    final width = MediaQuery.maybeSizeOf(context)?.width ?? 300;
    final scollSteps = layout.tabs.length / pagesOnScreen;
    final themeData = Theme.of(context);
    final colorExt = themeData.extension<CustomColors>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
                    if (layout.created == null)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          'bottom_sheets.dashboard_layout.layout_preview.not_saved',
                          style: TextStyle(color: themeData.colorScheme.onSecondary),
                        ).tr(),
                        backgroundColor: themeData.colorScheme.secondary,
                      ),
                    const SizedBox(width: 4),
                    if (isCurrent)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('general.current', style: TextStyle(color: themeData.colorScheme.onPrimary)).tr(),
                        backgroundColor: themeData.colorScheme.primary,
                      ),
                  ],
                ),
                const Divider(),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final availableTabs = layout.tabs.length;

                    final scrollWidth = constraints.maxWidth;
                    return SingleChildScrollView(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      child: IgnorePointer(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < max(availableTabs, pagesOnScreen); i++)
                              Builder(
                                builder: (ctx) {
                                  final tab = layout.tabs.elementAtOrNull(i);

                                  Widget child;
                                  if (tab == null || tab.components.isEmpty) {
                                    child = Padding(
                                      padding: EdgeInsets.symmetric(vertical: width / 4),
                                      child: SvgPicture.asset(
                                        'assets/vector/undraw_taken_re_yn20.svg',
                                        alignment: Alignment.center,
                                        width: width * 0.5,
                                      ),
                                    );
                                  } else {
                                    child = Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var card in tab.components) DasboardCard.preview(type: card.type),
                                      ],
                                    );
                                  }
                                  return ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: scrollWidth / pagesOnScreen),
                                    child: FittedBox(
                                      child: SizedBox(width: width, child: child),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
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
                  // Space required for the action buttons
                ],
                const SizedBox(height: 40),
              ],
            ),
            Positioned(
              bottom: 0,
              right: 0,
              left: 0,
              child: Wrap(
                alignment: WrapAlignment.end,
                verticalDirection: VerticalDirection.up,
                spacing: 4,
                children: [
                  if (layout.created != null)
                    ElevatedButton.icon(
                      onPressed: () => onTapDelete(layout),
                      style: ElevatedButton.styleFrom(
                        // elevation: 2,
                        foregroundColor: colorExt?.onDanger,
                        backgroundColor: colorExt?.danger,
                        visualDensity: VisualDensity.compact,
                        textStyle: themeData.textTheme.bodySmall,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('general.delete').tr(),
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
                      label: const Text('general.load').tr(),
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
    // We need to listen to all layout providers to ensure the UI reflects changes
    // Add the current layout to the list, if it is not already there
    if (!availableLayouts.any((element) => element.uuid == layout.uuid)) {
      // do not modify the original layout -> causes issues due to "Provider" changes
      availableLayouts.add(layout.copyWith());
    }

    // Sort by name and put the current layout on top
    availableLayouts.sort((a, b) {
      // Current layout should always be on top
      if (a.uuid == layout.uuid) return 0;
      if (b.uuid == layout.uuid) return 1;

      return a.name.compareTo(b.name);
    });

    return availableLayouts;
  }

  void onLayoutSelected(DashboardLayout layout) async {
    var confirm = await _dialogService.showConfirm(
      title: tr('bottom_sheets.dashboard_layout.load_layout_warning.title'),
      body: tr('bottom_sheets.dashboard_layout.load_layout_warning.body'),
    );
    if (confirm?.confirmed != true) return;

    returnLayout(layout);
  }

  void returnLayout(DashboardLayout layout) {
    _goRouter.pop(BottomSheetResult.confirmed(layout));
  }

  void onAddEmptyLayout() {
    final layout = _dashboardService.emptyDashboardLayout();
    returnLayout(layout);
  }

  Future<void> onImportLayout() async {
    talker.info('Importing layout from clipboard');
    try {
      var data = await Clipboard.getData('text/plain');
      if (data?.text == null) {
        talker.warning('Clipboard data is null or empty');
        _goRouter.pop();
        _snackBarService.show(
          SnackBarConfig(
            title: tr('bottom_sheets.dashboard_layout.falsy_import_snackbar.title'),
            message: tr('bottom_sheets.dashboard_layout.falsy_import_snackbar.body'),
            duration: const Duration(seconds: 10),
          ),
        );
        return;
      }
      final json = jsonDecode(data!.text!);

      final layout = ref.read(dashboardLayoutServiceProvider).importFromJson(json);

      returnLayout(layout);
      _snackBarService.show(
        SnackBarConfig(
          title: tr('bottom_sheets.dashboard_layout.import_snackbar.title'),
          message: tr('bottom_sheets.dashboard_layout.import_snackbar.body'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e, s) {
      talker.error('Error importing layout: $e');
      _snackBarService.show(
        SnackBarConfig.stacktraceDialog(
          dialogService: _dialogService,
          exception: e,
          stack: s,
          snackTitle: 'Error importing layout',
        ),
      );
    }
  }

  Future<void> onDeleteLayout(DashboardLayout layout) async {
    talker.info('Deleting layout ${layout.name} (${layout.uuid})#${identityHashCode(layout)}');

    final result = await _dialogService.showDangerConfirm(
      title: tr('bottom_sheets.dashboard_layout.delete_layout.title'),
      body: tr('bottom_sheets.dashboard_layout.delete_layout.body', args: [layout.name]),
      actionLabel: tr('general.delete'),
    );

    if (result?.confirmed == true) {
      await _dashboardService.removeLayout(layout);
      if (layout.uuid == this.layout.uuid) {
        returnLayout(_dashboardService.defaultDashboardLayout());
      } else {
        ref.invalidateSelf();
      }
    }
  }
}
