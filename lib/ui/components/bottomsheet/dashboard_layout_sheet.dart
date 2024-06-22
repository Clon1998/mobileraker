/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/payment_service.dart';
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
import 'package:flutter_svg/svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/horizontal_scroll_indicator.dart';
import 'package:mobileraker_pro/service/ui/dashboard_layout_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../dashboard_card.dart';
import '../dialog/text_input/text_input_dialog.dart';

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
                      'bottom_sheets.dashboard_layout.title',
                      style: themeData.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ).tr(),
                    // Text(
                    //   'Current Layout: ${currentLayout.name}',
                    //   style: themeData.textTheme.bodySmall,
                    //   textAlign: TextAlign.center,
                    // ),
                    Text.rich(
                      TextSpan(
                        text: '${tr('bottom_sheets.dashboard_layout.subtitle')} ',
                        children: [
                          TextSpan(
                            text: currentLayout.name,
                            // recognizer: TapGestureRecognizer()..onTap = () => controller.onRenameLayout(currentLayout),
                            style:
                                TextStyle(color: themeData.colorScheme.primary, decoration: TextDecoration.underline),
                          ),
                        ],
                      ),
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
                                child: AutoSizeText(tr('general.export'), maxLines: 1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: controller.onImportLayout,
                                child: AutoSizeText(tr('general.import'), maxLines: 1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    Text('bottom_sheets.dashboard_layout.available_layouts.label',
                            style: themeData.textTheme.labelLarge)
                        .tr(),
                    Expanded(
                      child: AsyncGuard(
                        debugLabel: 'Available Layouts-list',
                        toGuard: _dashboardLayoutControllerProvider(currentLayout).selectAs((d) => true),
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

    Share.share(str, subject: '${tr('bottom_sheets.dashboard_layout.title')}: ${currentLayout.name}');
  }
}

class _AvailableLayouts extends ConsumerWidget {
  const _AvailableLayouts({super.key, required this.scrollController, required this.currentLayout});

  final ScrollController scrollController;
  final DashboardLayout currentLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var aa = ref.watch(_dashboardLayoutControllerProvider(currentLayout));
    final availableLayouts = aa.requireValue;
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
                onTapDelete: (l) => controller.onDeleteLayout(l),
                onTapReset: controller.onResetLayout,
                onTapRename: (l) => controller.onRenameLayout(l),
              ),
          ],
        ),
        if (availableLayouts.isEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Center(
                child: Text('bottom_sheets.dashboard_layout.available_layouts.empty', style: theme.textTheme.bodySmall)
                    .tr(),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: ElevatedButton.icon(
            onPressed: controller.onAddEmptyLayout,
            icon: const Icon(Icons.add),
            label: const Text('bottom_sheets.dashboard_layout.available_layouts.add_empty').tr(),
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
    required this.onTapRename,
  });

  final DashboardLayout layout;
  final bool isCurrent;
  final void Function(DashboardLayout layout) onTapLoad;
  final void Function(DashboardLayout layout) onTapDelete;
  final void Function(DashboardLayout layout) onTapReset;
  final void Function(DashboardLayout layout) onTapRename;
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
                              Builder(builder: (ctx) {
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
                                    child: SizedBox(
                                      width: width,
                                      child: child,
                                    ),
                                  ),
                                );
                              }),
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
                  ElevatedButton.icon(
                    onPressed: () => onTapRename(layout),
                    style: ElevatedButton.styleFrom(
                      // elevation: 2,
                      visualDensity: VisualDensity.compact,
                      textStyle: themeData.textTheme.bodySmall,
                      foregroundColor: themeData.colorScheme.onSecondaryContainer,
                      backgroundColor: themeData.colorScheme.secondaryContainer,
                    ),
                    icon: const Icon(Icons.abc, size: 18),
                    label: const Text('general.rename').tr(),
                  ),
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
                      label: const Text('pages.dashboard.general.print_card.reset').tr(),
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
    logger.i('Importing layout from clipboard');
    try {
      var data = await Clipboard.getData('text/plain');
      if (data?.text == null) {
        logger.w('Clipboard data is null or empty');
        _snackBarService.show(SnackBarConfig(
          title: tr('bottom_sheets.dashboard_layout.falsy_import_snackbar.title'),
          message: tr('bottom_sheets.dashboard_layout.falsy_import_snackbar.body'),
          duration: const Duration(seconds: 10),
        ));
        return;
      }
      final json = jsonDecode(data!.text!);

      final layout = ref.read(dashboardLayoutServiceProvider).importFromJson(json);

      onLayoutSelected(layout);
      _snackBarService.show(SnackBarConfig(
        title: tr('bottom_sheets.dashboard_layout.import_snackbar.title'),
        message: tr('bottom_sheets.dashboard_layout.import_snackbar.body'),
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

  Future<void> onRenameLayout(DashboardLayout layout) async {
    logger.i('Renaming layout ${layout.name} (${layout.uuid})#${identityHashCode(layout)}');

    var isSupporter = ref.read(isSupporterProvider);

    if (!isSupporter) {
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.warning,
        title: tr('components.supporter_only_feature.dialog_title'),
        message: tr('components.supporter_only_feature.custom_dashboard'),
        duration: const Duration(seconds: 5),
      ));
      return;
    }

    final result = await _dialogService.show(DialogRequest(
      type: DialogType.textInput,
      actionLabel: tr('general.rename'),
      title: tr('bottom_sheets.dashboard_layout.rename_layout.title'),
      data: TextInputDialogArguments(
        initialValue: layout.name,
        labelText: tr('bottom_sheets.dashboard_layout.rename_layout.label'),
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(),
          FormBuilderValidators.minLength(3),
          FormBuilderValidators.maxLength(40),
        ]),
      ),
    ));

    if (result case DialogResponse(confirmed: true, data: String newName) when newName != layout.name) {
      layout.name = newName;
      await _dashboardService.persistLayout(layout);
      // TODO: This works, but reloads the whole list. Should be optimized to only replace the changed layout
      ref.invalidateSelf();
    }
  }

  Future<void> onDeleteLayout(DashboardLayout layout) async {
    logger.i('Deleting layout ${layout.name} (${layout.uuid})#${identityHashCode(layout)}');

    final result = await _dialogService.showDangerConfirm(
      title: tr('bottom_sheets.dashboard_layout.delete_layout.title'),
      body: tr('bottom_sheets.dashboard_layout.delete_layout.body', args: [layout.name]),
      actionLabel: tr('general.delete'),
    );

    if (result?.confirmed == true) {
      await _dashboardService.removeLayout(layout);
      // TODO: This works, but reloads the whole list. Should be optimized to only remove the deleted layout
      if (layout.uuid == this.layout.uuid) {
        onLayoutSelected(_dashboardService.defaultDashboardLayout());
      } else {
        ref.invalidateSelf();
      }
    }
  }
}
