/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/data/dto/files/moonraker/file_action_response.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/enums/file_action_enum.dart';
import 'package:common/data/enums/file_action_sheet_action_enum.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/file_interaction_menu_event.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/exceptions/file_fetch_exception.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/path_utils.dart';
import 'package:common/util/time_util.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg/svg.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/file_interaction_service.dart';
import 'package:mobileraker/ui/components/bottomsheet/settings_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker/ui/components/job_queue_fab.dart';
import 'package:mobileraker/ui/screens/files/components/remote_file_list_tile.dart';
import 'package:mobileraker_pro/ads/ad_block_unit.dart';
import 'package:mobileraker_pro/ads/ui/ad_banner.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:persistent_header_adaptive/persistent_header_adaptive.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stringr/stringr.dart';

import '../../../routing/app_router.dart';
import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../components/connection/machine_connection_guard.dart';
import 'components/shimmer_file_list.dart';
import 'components/sorted_file_list_header.dart';

part 'file_manager_page.freezed.dart';
part 'file_manager_page.g.dart';

class FileManagerPage extends HookConsumerWidget {
  const FileManagerPage({super.key, required this.filePath, this.folder});

  final String filePath;
  final Folder? folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController(keys: [filePath]);
    final isRoot = filePath.split('/').length == 1;

    Widget body = MachineConnectionGuard(
      skipKlipperReady: true,
      onConnected: (ctx, machineUUID) =>
          _Body(machineUUID: machineUUID, filePath: filePath, scrollController: scrollController),
    );
    final fab = _Fab(filePath: filePath, scrollController: scrollController);
    if (context.isLargerThanCompact && isRoot) {
      body = NavigationRailView(
        // leading: fab,
        page: Padding(padding: const EdgeInsets.only(left: 2.0), child: body),
      );
    }

    return PrimaryScrollController(
      controller: scrollController,
      child: Scaffold(
        appBar: _AppBar(filePath: filePath, folder: folder),
        drawer: const NavigationDrawerWidget().only(isRoot),
        bottomNavigationBar: _BottomNav(filePath: filePath).unless(context.isLargerThanCompact),
        floatingActionButton: fab,
        body: body,
      ),
    );
  }
}

class _AppBar extends HookConsumerWidget implements PreferredSizeWidget {
  const _AppBar({super.key, required this.filePath, this.folder});

  final String filePath;

  final Folder? folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final split = filePath.split('/');
    final isRoot = split.length == 1;
    final title = split.last;
    final selMachine = ref.watch(selectedMachineProvider).valueOrNull;

    if (selMachine == null) {
      return AppBar(title: Text(title.capitalize()));
    }

    return Consumer(
      builder: (context, ref, _) {
        final controller = ref.watch(_modernFileManagerControllerProvider(selMachine.uuid, filePath).notifier);
        final isSelecting = ref.watch(
          _modernFileManagerControllerProvider(selMachine.uuid, filePath).select((data) => data.selectionMode),
        );

        final actions = [
          IconButton(
            tooltip: tr('pages.files.search_files'),
            icon: const Icon(Icons.search),
            onPressed: controller.onClickSearch,
          ),
          if (!isRoot)
            Consumer(
              builder: (context, ref, _) {
                final actualFolder = ref.watch(remoteFileProvider(selMachine.uuid, filePath)).valueOrNull ?? folder;

                return IconButton(
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final pos = box!.localToGlobal(Offset.zero) & box.size;

                    controller.onClickFileAction(actualFolder!, pos);
                  }.unless(actualFolder == null),
                );
              },
            ),
        ];

        final defaultBar = isRoot
            ? SwitchPrinterAppBar(key: const Key('file_manager_app_bar'), title: title.capitalize(), actions: actions)
            : AppBar(key: const Key('file_manager_app_bar'), title: Text(title.capitalize()), actions: actions);

        return AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          child: isSelecting ? _buildSelectioAppBar(context, controller) : defaultBar,
        );
      },
    );
  }

  Widget _buildSelectioAppBar(BuildContext context, _ModernFileManagerController controller) {
    var materialLocalizations = MaterialLocalizations.of(context);
    return AppBar(
      key: const Key('file_manager_selection_app_bar'),
      leading: IconButton(
        tooltip: materialLocalizations.clearButtonTooltip,
        icon: const Icon(Icons.close),
        onPressed: controller.onClickClearSelection,
      ),
      actions: [
        IconButton(
          tooltip: tr('pages.files.file_actions.move'),
          icon: const Icon(Icons.drive_file_move),
          onPressed: controller.onClickMoveSelected,
        ),
        IconButton(
          tooltip: materialLocalizations.selectAllButtonLabel,
          icon: const Icon(Icons.select_all),
          onPressed: controller.onClickSelectAll,
        ),
        IconButton(
          tooltip: materialLocalizations.moreButtonTooltip,
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            final box = context.findRenderObject() as RenderBox?;
            final pos = box!.localToGlobal(Offset.zero) & box.size;

            controller.onClickMoreActionsSelected(pos);
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _Fab extends HookConsumerWidget {
  const _Fab({super.key, required this.filePath, required this.scrollController});

  final String filePath;

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMachine = ref.watch(selectedMachineProvider).valueOrNull;

    if (selectedMachine == null) {
      return const SizedBox.shrink();
    }

    return HookConsumer(
      builder: (context, ref, _) {
        final controller = ref.watch(_modernFileManagerControllerProvider(selectedMachine.uuid, filePath).notifier);
        final (isUploading, isDownloading, isUpOrDownloadDone, isFilesLoading, isSelecting) = ref.watch(
          _modernFileManagerControllerProvider(selectedMachine.uuid, filePath).select((data) {
            return (
              data.upload != null,
              data.download != null,
              data.download is FileDownloadComplete || data.upload is FileUploadComplete,
              data.folderContent.isLoading,
              data.selectionMode,
            );
          }),
        );

        final isUpOrDownloading = isUploading || isDownloading;

        final connected = ref.watch(
          jrpcClientStateProvider(selectedMachine.uuid).select((d) => d.valueOrNull == ClientState.connected),
        );

        final isScrolling = useState(false);
        useEffect(() {
          if (isUpOrDownloading) {
            isScrolling.value = false;
            return null;
          }

          double last = scrollController.hasClients ? scrollController.offset : 0;
          isScrolling.value = false;
          listener() {
            if (!scrollController.hasClients) {
              isScrolling.value = false;
              return;
            }
            if (scrollController.position.userScrollDirection == ScrollDirection.reverse) {
              if (!isScrolling.value && scrollController.offset - last > 25) {
                isScrolling.value = true;
              }
            } else if (scrollController.position.userScrollDirection == ScrollDirection.forward) {
              // check if delta is gt 10
              last = scrollController.offset;
              isScrolling.value = false;
            }
          }

          scrollController.addListener(listener);
          return () => scrollController.removeListener(listener);
        }, [scrollController, filePath, isSelecting, isUpOrDownloading]);

        final children = [
          if (filePath == 'gcodes') ...[
            AnimatedSwitcher(
              duration: kThemeAnimationDuration,
              switchInCurve: Curves.easeInOutCubicEmphasized,
              switchOutCurve: Curves.easeInOutCubicEmphasized,
              // duration: kThemeAnimationDuration,
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: JobQueueFab(
                machineUUID: selectedMachine.uuid,
                onPressed: controller.onClickJobQueueFab,
                mini: true,
                hideIfEmpty: true,
              ),
            ),
            const Gap(4),
          ],
          if (!isUpOrDownloading)
            FloatingActionButton(
              heroTag: '${selectedMachine.uuid}-main',
              onPressed: () {
                final box = context.findRenderObject() as RenderBox?;
                final pos = box!.localToGlobal(Offset.zero) & box.size;
                controller.onClickAddFileFab(pos);
              }.only(!isFilesLoading),
              child: const Icon(Icons.add),
            ),
          if (isUpOrDownloading && !isUpOrDownloadDone)
            FloatingActionButton.extended(
              heroTag: '${selectedMachine.uuid}-main',
              onPressed: controller.onClickCancelUpOrDownload,
              label: const Text('pages.files.cancel_fab').tr(gender: isUploading ? 'upload' : 'download'),
            ),
          if (isUpOrDownloadDone)
            FloatingActionButton(
              heroTag: '${selectedMachine.uuid}-main',
              onPressed: null,
              child: const Icon(Icons.done),
            ),
        ];
        final fab = Column(
          key: const Key('file_manager_fab'),
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: isUpOrDownloading ? CrossAxisAlignment.end : CrossAxisAlignment.center,
          children: children,
        );
        return AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          switchInCurve: Curves.easeInOutCubicEmphasized,
          switchOutCurve: Curves.easeInOutCubicEmphasized,
          // duration: kThemeAnimationDuration,
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: isScrolling.value || !connected || filePath == 'timelapse' || isSelecting && !isUpOrDownloading
              ? const SizedBox.shrink(key: Key('file_manager_fab-hidden'))
              : fab,
        );
      },
    );
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav({super.key, String? filePath}) : filePath = filePath ?? 'gcodes';

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMachine = ref.watch(selectedMachineProvider).valueOrNull;

    if (selectedMachine == null || filePath.split('/').length > 1) {
      return const SizedBox.shrink();
    }

    final connected = ref.watch(
      jrpcClientStateProvider(selectedMachine.uuid).select((d) => d.valueOrNull == ClientState.connected),
    );
    if (!connected) {
      return const SizedBox.shrink();
    }

    final controller = ref.watch(_modernFileManagerControllerProvider(selectedMachine.uuid, filePath).notifier);

    final (inSelectionMode, hasTimelapseComponent) = ref.watch(
      _modernFileManagerControllerProvider(
        selectedMachine.uuid,
        filePath,
      ).select((data) => (data.selectionMode, data.hasTimelapseComponent)),
    );

    // 1 => 'config',
    // 2 => 'timelapse',
    // _ => 'gcodes',

    final int activeIndex;
    if (filePath.startsWith('config')) {
      activeIndex = 1;
    } else if (filePath.startsWith('timelapse')) {
      activeIndex = 2;
    } else {
      activeIndex = 0;
    }

    // ref.watch(provider)
    var navigationBar = BottomNavigationBar(
      key: const Key('file_manager_bottom_nav'),
      showSelectedLabels: true,
      currentIndex: activeIndex,
      // onTap: ref.read(filePageProvider.notifier).onPageTapped,
      onTap: controller.onClickRootNavigation,
      items: [
        BottomNavigationBarItem(
          label: tr('pages.files.gcode_tab'),
          icon: const Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
        ),
        BottomNavigationBarItem(label: tr('pages.files.config_tab'), icon: const Icon(FlutterIcons.file_code_faw5)),
        if (hasTimelapseComponent)
          BottomNavigationBarItem(
            label: tr('pages.files.timelapse_tab'),
            icon: const Icon(Icons.subscriptions_outlined),
          ),
      ],
    );
    const dur = kThemeAnimationDuration;
    return AnimatedSizeAndFade(
      fadeDuration: dur,
      sizeDuration: dur,
      fadeInCurve: Curves.easeInOutCubicEmphasized,
      fadeOutCurve: Curves.easeInOutCubicEmphasized.flipped,
      sizeCurve: Curves.easeInOutCubicEmphasized,
      child: inSelectionMode ? const SizedBox.shrink(key: Key('file_manager_bottom_nav-hidden')) : navigationBar,
    );
  }
}

class _TabbarNav extends HookConsumerWidget {
  const _TabbarNav({super.key, required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMachine = ref.watch(selectedMachineProvider).valueOrNull;

    if (selectedMachine == null || filePath.split('/').length > 1) {
      return const SizedBox.shrink();
    }

    final connected = ref.watch(
      jrpcClientStateProvider(selectedMachine.uuid).select((d) => d.valueOrNull == ClientState.connected),
    );
    if (!connected) {
      return const SizedBox.shrink();
    }

    final controller = ref.watch(_modernFileManagerControllerProvider(selectedMachine.uuid, filePath).notifier);

    final (inSelectionMode, hasTimelapseComponent) = ref.watch(
      _modernFileManagerControllerProvider(
        selectedMachine.uuid,
        filePath,
      ).select((data) => (data.selectionMode, data.hasTimelapseComponent)),
    );

    // 1 => 'config',
    // 2 => 'timelapse',
    // _ => 'gcodes',
    final int activeIndex;
    if (filePath.startsWith('config')) {
      activeIndex = 1;
    } else if (filePath.startsWith('timelapse') && hasTimelapseComponent) {
      activeIndex = 2;
    } else {
      activeIndex = 0;
    }
    final tabController = useTabController(initialLength: hasTimelapseComponent ? 3 : 2, initialIndex: activeIndex);

    if (tabController.index != activeIndex && !tabController.indexIsChanging) {
      tabController.index = activeIndex;
    }

    var themeData = Theme.of(context);
    final tabBar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TabBar(
          key: const Key('file_manager_tabbar'),
          indicatorColor: themeData.colorScheme.primary,
          labelColor: themeData.colorScheme.primary,
          unselectedLabelColor: themeData.disabledColor,
          controller: tabController,
          onTap: controller.onClickRootNavigation,
          enableFeedback: true,
          tabs: [
            Tab(text: tr('pages.files.gcode_tab'), icon: const Icon(FlutterIcons.printer_3d_nozzle_outline_mco)),
            Tab(text: tr('pages.files.config_tab'), icon: const Icon(FlutterIcons.file_code_faw5)),
            if (hasTimelapseComponent)
              Tab(text: tr('pages.files.timelapse_tab'), icon: const Icon(Icons.subscriptions_outlined)),
          ],
        ),
        if (!themeData.useMaterial3) Divider(height: 1, thickness: 1, color: themeData.colorScheme.primary),
      ],
    );

    return IgnorePointer(ignoring: inSelectionMode, child: tabBar);
  }
}

class _Body extends StatelessWidget {
  const _Body({super.key, required this.machineUUID, required this.filePath, required this.scrollController});

  final String machineUUID;

  final String filePath;

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLimit(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (context.isLargerThanCompact) _TabbarNav(filePath: filePath),
          Expanded(
            child: _FileList(machineUUID: machineUUID, filePath: filePath, scrollController: scrollController),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({super.key, required this.machineUUID, required this.filePath, this.enabled = true});

  final String machineUUID;

  final String filePath;

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_modernFileManagerControllerProvider(machineUUID, filePath).notifier);
    final (sortCfg, apiLoading, isSelecting) = ref.watch(
      _modernFileManagerControllerProvider(
        machineUUID,
        filePath,
      ).select((data) => (data.sortConfiguration, data.folderContent.isLoading, data.selectionMode)),
    );

    final themeData = Theme.of(context);

    return SortedFileListHeader(
      activeSortConfig: sortCfg,
      onTapSortMode: controller.onClickSortMode.only(!apiLoading).only(enabled),
      trailing: IconButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // 12 is basis vom icon button + 4 weil list tile hat 14 padding + 1 wegen size 22
        onPressed: controller.onClickSettings,
        icon: Icon(Icons.settings, size: 18, color: themeData.textTheme.bodySmall?.color),
      ).unless(isSelecting),
    );
  }
}

class _FileList extends ConsumerWidget {
  const _FileList({super.key, required this.machineUUID, required this.filePath, required this.scrollController});

  final String machineUUID;

  final String filePath;

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderContent = ref.watch(
      _modernFileManagerControllerProvider(machineUUID, filePath).select((data) => data.folderContent),
    );

    final widget = switch (folderContent) {
      AsyncValue(hasValue: true, value: FolderContentWrapper() && final content) => _FileListData(
        key: Key('$filePath-list'),
        machineUUID: machineUUID,
        filePath: filePath,
        folderContent: content,
        scrollController: scrollController,
      ),
      AsyncError(:final error, :final stackTrace) => _FileListError(
        key: Key('$filePath-list-error'),
        machineUUID: machineUUID,
        filePath: filePath,
        error: error,
        stack: stackTrace,
      ),
      _ => const ShimmerFileList(),
    };

    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      switchInCurve: Curves.easeInOutSine,
      switchOutCurve: Curves.easeInOutSine.flipped,
      // switchInCurve: Curves.easeInOutCubicEmphasized,
      // switchOutCurve: Curves.easeInOutCubicEmphasized.flipped,
      child: widget,
    );
  }
}

class _FileListError extends ConsumerWidget {
  const _FileListError({
    super.key,
    required this.machineUUID,
    required this.filePath,
    required this.error,
    required this.stack,
  });

  final String machineUUID;
  final String filePath;
  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (error is FileFetchException) {
      FileFetchException ffe = error as FileFetchException;
      String message = ffe.message;
      if (ffe.parent != null) {
        message += '\n${ffe.parent}';
      }

      var themeData = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SimpleErrorWidget(
            title: Text('Unable to fetch files!', style: themeData.textTheme.titleMedium),
            body: Text(message, textAlign: TextAlign.center, style: themeData.textTheme.bodySmall),
            action: TextButton.icon(
              onPressed: () => ref
                  .read(_modernFileManagerControllerProvider(machineUUID, filePath).notifier)
                  .refreshApiResponse(true),
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text('general.retry').tr(),
            ),
          ),
        ),
      );
    }

    return ErrorCard(
      title: const Text('Unable to fetch files!'),
      body: Column(
        children: [
          Text('The following error occued while trying to fetch files:n$error'),
          TextButton(
            // onPressed: model.showPrinterFetchingErrorDialog,
            onPressed: () => ref
                .read(dialogServiceProvider)
                .show(
                  DialogRequest(
                    type: CommonDialogs.stacktrace,
                    title: error.runtimeType.toString(),
                    body: 'Exception:\n$error\n\n$stack',
                  ),
                ),
            child: const Text('Show Full Error'),
          ),
        ],
      ),
    );
  }
}

class _FileListData extends ConsumerStatefulWidget {
  const _FileListData({
    super.key,
    required this.machineUUID,
    required this.filePath,
    required this.folderContent,
    required this.scrollController,
  });

  final String machineUUID;

  final String filePath;

  final FolderContentWrapper folderContent;

  final ScrollController scrollController;

  @override
  ConsumerState createState() => _FileListState();
}

class _FileListState extends ConsumerState<_FileListData> {
  final RefreshController _refreshController = RefreshController();

  ValueNotifier<bool> _isUserRefresh = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMd(context.deviceLocale.languageCode));
    final controller = ref.watch(_modernFileManagerControllerProvider(widget.machineUUID, widget.filePath).notifier);
    final sortConfiguration = ref.watch(
      _modernFileManagerControllerProvider(
        widget.machineUUID,
        widget.filePath,
      ).select((data) => data.sortConfiguration),
    );

    final int totalItems = widget.folderContent.totalItems;
    final adEvery = ref.watch(remoteConfigIntProvider('files_page_add_density'));

    final int adCount = adEvery > 0 ? totalItems ~/ adEvery : 0;

    final themeData = Theme.of(context);
    // Note Wrapping the listview in the SmartRefresher causes the UI to "Lag" because it renders the entire listview at once rather than making use of the builder???
    return SmartRefresher(
      // header: const WaterDropMaterialHeader(),
      controller: _refreshController,
      onRefresh: () {
        _isUserRefresh.value = true;
        controller
            .refreshApiResponse()
            .then(
              (_) {
                _refreshController.refreshCompleted();
              },
              onError: (e, s) {
                talker.error('Error while refreshing FileListState', e, s);
                _refreshController.refreshFailed();
              },
            )
            .whenComplete(() => _isUserRefresh.value = false);
      },
      child: CustomScrollView(
        key: PageStorageKey('${widget.filePath}:${sortConfiguration.mode}:${sortConfiguration.kind}'),
        controller: widget.scrollController,
        slivers: [
          AdaptiveHeightSliverPersistentHeader(
            floating: true,
            initialHeight: 48,
            needRepaint: true,
            child: _Header(
              machineUUID: widget.machineUUID,
              filePath: widget.filePath,
              enabled: widget.folderContent.isNotEmpty,
            ),
          ),
          AdaptiveHeightSliverPersistentHeader(
            initialHeight: 4,
            pinned: true,
            child: _LoadingIndicator(
              machineUUID: widget.machineUUID,
              filePath: widget.filePath,
              isUserRefresh: _isUserRefresh,
            ),
          ),
          if (widget.folderContent.isEmpty)
            SliverFillRemaining(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: 0.3,
                      child: SvgPicture.asset('assets/vector/undraw_void_-3-ggu.svg'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('pages.files.empty_folder.title', style: themeData.textTheme.titleMedium).tr(),
                  Text('pages.files.empty_folder.subtitle', style: themeData.textTheme.bodySmall).tr(),
                ],
              ),
            ),
          if (widget.folderContent.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(bottom: kFloatingActionButtonMargin * 2 + 48),
              sliver: SliverList.separated(
                separatorBuilder: (context, index) => const Divider(height: 0, indent: 18, endIndent: 18),
                itemCount: widget.folderContent.totalItems + adCount,
                itemBuilder: (context, index) {
                  if (adEvery > 0 && index > 0 && index % (adEvery + 1) == adEvery) {
                    // Calculate which ad to show (0-based index for ads)
                    final adIndex = (index ~/ (adEvery + 1));

                    return LayoutBuilder(
                      key: Key('file_list_ad:$adIndex:${widget.filePath}'),
                      builder: (context, constraints) {
                        return InlineAdaptiveAdBanner(
                          unit: AdBlockUnit.fileManagerPage,
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                          animated: false,
                        );
                      },
                    );
                  }

                  // Calculate the actual index in your data, accounting for the ad positions
                  final int dataIndex = adEvery > 0 ? index - (index ~/ (adEvery + 1)) : index;

                  final file = widget.folderContent.unwrapped[dataIndex];
                  return _FileItem(
                    key: ValueKey(file),
                    machineUUID: widget.machineUUID,
                    file: file,
                    dateFormat: dateFormat,
                    sortMode: sortConfiguration.mode,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}

class _LoadingIndicator extends HookConsumerWidget {
  const _LoadingIndicator({super.key, required this.machineUUID, required this.filePath, required this.isUserRefresh});

  final String machineUUID;

  final String filePath;

  final ValueNotifier<bool> isUserRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_modernFileManagerControllerProvider(machineUUID, filePath));

    final wasUser = useValueListenable(isUserRefresh);

    double? value = switch (model) {
      _Model(download: FileOperationProgress(:final progress)) ||
      _Model(upload: FileOperationProgress(:final progress)) => progress,
      _Model(folderContent: AsyncValue(isLoading: true)) ||
      _Model(download: FileOperationKeepAlive()) when !wasUser => null,
      _ => 0,
    };
    return LinearProgressIndicator(backgroundColor: Colors.transparent, value: value);
  }
}

class _FileItem extends ConsumerWidget {
  const _FileItem({
    super.key,
    required this.machineUUID,
    required this.file,
    required this.dateFormat,
    required this.sortMode,
  });

  final String machineUUID;
  final RemoteFile file;
  final DateFormat dateFormat;
  final SortMode sortMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_modernFileManagerControllerProvider(machineUUID, file.parentPath).notifier);

    final (selected, selectionMode, enabled) = ref.watch(
      _modernFileManagerControllerProvider(machineUUID, file.parentPath).select(
        (d) => (
          d.selectedFiles.contains(file),
          d.selectionMode,
          d.folderContent.isLoading == false && !d.isOperationActive,
        ),
      ),
    );

    var numberFormat = NumberFormat.decimalPatternDigits(
      locale: context.locale.toStringWithSeparator(),
      decimalDigits: 1,
    );

    Widget subtitle = switch (sortMode) {
      SortMode.size => Text(numberFormat.formatFileSize(file.size)),
      SortMode.estimatedPrintTime when file is GCodeFile => Text(
        (file as GCodeFile).estimatedTime?.let(secondsToDurationText) ?? '--',
      ),
      SortMode.lastPrinted when file is GCodeFile => Text(
        (file as GCodeFile).lastPrintDate?.let(dateFormat.format) ?? '--',
      ),
      SortMode.lastPrinted => const Text('--'),
      SortMode.lastModified => Text(file.modifiedDate?.let(dateFormat.format) ?? '--'),
      _ => Text('@:pages.files.sort_by.last_modified: ${file.modifiedDate?.let(dateFormat.format) ?? '--'}').tr(),
    };

    return RemoteFileListTile(
      machineUUID: machineUUID,
      file: file,
      selected: selected,
      subtitle: subtitle,
      showPrintedIndicator: true,
      trailing: AnimatedSizeAndFade(
        fadeDuration: kThemeAnimationDuration,
        sizeDuration: kThemeAnimationDuration,
        fadeInCurve: Curves.easeInOutCubicEmphasized,
        fadeOutCurve: Curves.easeInOutCubicEmphasized.flipped,
        sizeCurve: Curves.easeInOutCubicEmphasized,
        child: selectionMode
            ? const SizedBox.shrink()
            : IconButton(
                key: Key('file_item_more_button_${file.hashCode}'),
                icon: const Icon(Icons.more_horiz, size: 22),
                onPressed: () {
                  final box = context.findRenderObject() as RenderBox?;
                  final pos = box!.localToGlobal(Offset.zero) & box.size;

                  controller.onClickFileAction(file, pos);
                }.only(enabled),
              ),
      ),
      onTap: () {
        if (selectionMode) {
          controller.onLongClickFile(file);
        } else {
          final box = context.findRenderObject() as RenderBox?;
          final pos = box!.localToGlobal(Offset.zero) & box.size;
          controller.onClickFile(file, pos);
        }
      }.only(enabled),
      onLongPress: () {
        controller.onLongClickFile(file);
      }.only(enabled),
    );
  }
}

@riverpod
class _ModernFileManagerController extends _$ModernFileManagerController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  SettingService get _settingService => ref.read(settingServiceProvider);

  FileInteractionService get _fileInteractionService => ref.read(fileInteractionServiceProvider(machineUUID));

  // ignore: avoid-unsafe-collection-methods
  String get _root => filePath.split('/').first;

  List<SortMode> get _availableSortModes => switch (_root) {
    'gcodes' => SortMode.availableForGCodes(),
    _ => SortMode.availableForFiles(),
  };

  CompositeKey get _sortModeKey => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, 'mode:$_root');

  CompositeKey get _sortKindKey => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, 'kind:$_root');

  CancelToken? _downloadToken;

  CancelToken? _uploadToken;

  FileActionResponse? _lastResponse;

  @override
  _Model build(String machineUUID, [String filePath = 'gcodes']) {
    ref.keepAliveFor();
    // Since this might be used with file actions!
    ref.keepAliveExternally(printerProvider(machineUUID));
    ref.listen(fileNotificationsProvider(machineUUID, filePath), _onFileNotification, fireImmediately: true);

    ref.listen(jrpcClientStateProvider(machineUUID), _onJrpcStateNotification);
    ref.onCancel(() => _downloadToken?.cancel());
    ref.onCancel(() => _uploadToken?.cancel());
    listenSelf(_onModelChanged);

    talker.info('[ModernFileManagerController($machineUUID, $filePath)] fetching directory info for $filePath');

    final supportedModes = _availableSortModes;
    final sortModeIdx = ref.watch(intSettingProvider(_sortModeKey)).clamp(0, supportedModes.length - 1);
    final sortKindIdx = ref.watch(intSettingProvider(_sortKindKey)).clamp(0, SortKind.values.length - 1);

    final hasTimelapseComponent = ref.watch(
      klipperProvider(machineUUID).select((d) => d.valueOrNull?.hasTimelapseComponent == true),
    );

    // ignore: avoid-unsafe-collection-methods
    final sortConfiguration = SortConfiguration(supportedModes[sortModeIdx], SortKind.values[sortKindIdx]);

    var apiResp = ref.watch(moonrakerFolderContentProvider(machineUUID, filePath, sortConfiguration));

    talker.info('[ModernFileManagerController($machineUUID, $filePath)] The api response is: $apiResp ');
    talker.info('[ModernFileManagerController($machineUUID, $filePath)] and the current state is: $stateOrNull');

    // Required to get a smoother UX and to prevent the folder content from beeing empty!
    if (stateOrNull != null) {
      apiResp = apiResp.copyWithPrevious(stateOrNull!.folderContent, isRefresh: apiResp.isRefreshing);
    }

    return _Model(
      selectedFiles: stateOrNull?.selectedFiles ?? [],
      folderContent: apiResp,
      sortConfiguration: sortConfiguration,
      download: stateOrNull?.download,
      upload: stateOrNull?.upload,
      hasTimelapseComponent: hasTimelapseComponent,
    );
  }

  void onClickFile(RemoteFile file, Rect origin) {
    talker.info(
      '[ModernFileManagerController($machineUUID, $filePath)] opening file ${file.name} (${file.runtimeType})',
    );

    switch (file) {
      case GCodeFile():
        _goRouter.pushNamed(
          AppRoute.fileManager_exlorer_gcodeDetail.name,
          pathParameters: {'path': filePath},
          extra: file,
        );
        break;
      case Folder():
        _goRouter.pushNamed(
          AppRoute.fileManager_explorer.name,
          pathParameters: {'path': file.absolutPath},
          extra: file,
        );
        break;
      case RemoteFile(isVideo: true):
        _goRouter.pushNamed(
          AppRoute.fileManager_exlorer_videoPlayer.name,
          pathParameters: {'path': filePath},
          extra: file,
        );
        break;
      case RemoteFile(isImage: true):
        _goRouter.pushNamed(
          AppRoute.fileManager_exlorer_imageViewer.name,
          pathParameters: {'path': filePath},
          extra: file,
        );
        break;
      case RemoteFile(isArchive: true):
        var fileAction = _fileInteractionService
            .downloadFileAction([file], origin)
            .endWith(FileOperationCompleted(action: FileSheetAction.download, files: [file]));
        _handleFileInteractionEventStream(fileAction);
        break;
      default:
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_editor.name, pathParameters: {'path': filePath}, extra: file);
    }
  }

  void onLongClickFile(RemoteFile file) {
    talker.info('[ModernFileManagerController($machineUUID, $filePath)] file longPress: ${file.name}');
    // _goRouter.pushNamed(AppRoute.fileManager_explorer.name, pathParameters: {'path': file.absolutPath});

    // if not in selected, add
    if (!state.selectedFiles.contains(file)) {
      state = state.copyWith(selectedFiles: [...state.selectedFiles, file]);
    } else {
      // if in selected, remove
      state = state.copyWith(selectedFiles: state.selectedFiles.where((it) => it != file).toList());
    }
  }

  Future<void> onClickFileAction(RemoteFile file, Rect origin) async {
    await _handleFileInteractionEventStream(
      _fileInteractionService.showFileActionMenu(
        file,
        origin,
        machineUUID,
        stateOrNull?.folderContent.requireValue.folderFileNames,
      ),
    );
  }

  void onClickRootNavigation(int index) {
    talker.info('[ModernFileManagerController($machineUUID, $filePath)] bottom nav item tapped: $index');

    switch (index) {
      case 1:
        _goRouter.replaceNamed(AppRoute.fileManager_explorer.name, pathParameters: {'path': 'config'});
        break;
      case 2:
        _goRouter.replaceNamed(AppRoute.fileManager_explorer.name, pathParameters: {'path': 'timelapse'});
        break;
      default:
        _goRouter.replaceNamed(AppRoute.fileManager_explorer.name, pathParameters: {'path': 'gcodes'});
    }
  }

  void onClickSettings() {
    talker.info('[ModernFileManagerController($machineUUID, $filePath)] opening settings');
    _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.changeSettings,
        data: SettingsBottomSheetArgs(
          title: tr('bottom_sheets.file_manager_settings.title'),
          settings: [
            SwitchSettingItem(
              settingKey: AppSettingKeys.hideBackupFiles,
              title: tr('bottom_sheets.file_manager_settings.hide_backup_files.title'),
              subtitle: tr('bottom_sheets.file_manager_settings.hide_backup_files.subtitle'),
              defaultValue: false,
            ),
            SwitchSettingItem(
              settingKey: AppSettingKeys.showHiddenFiles,
              title: tr('bottom_sheets.file_manager_settings.show_hidden_files.title'),
              subtitle: tr('bottom_sheets.file_manager_settings.show_hidden_files.subtitle'),
              defaultValue: false,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> onClickSortMode() async {
    talker.info('[ModernFileManagerController($machineUUID, $filePath)] sort mode');
    final args = SortModeSheetArgs(toShow: _availableSortModes, active: state.sortConfiguration);

    final res = await _bottomSheetService.show(BottomSheetConfig(type: SheetType.sortMode, data: args));

    if (res.confirmed == true) {
      talker.info('SortModeSheet confirmed: ${res.data}');

      // This is required to already show the new sort mode before the data is updated
      state = state.copyWith(sortConfiguration: res.data);
      // This will trigger a rebuild!
      _settingService.writeInt(_sortModeKey, res.data.mode.index);
      _settingService.writeInt(_sortKindKey, res.data.kind.index);
    }
  }

  void onClickSearch() {
    talker.info('[ModernFileManagerController($machineUUID, $filePath)] search');

    _goRouter.pushNamed(
      AppRoute.fileManager_exlorer_search.name,
      pathParameters: {'path': filePath},
      queryParameters: {'machineUUID': machineUUID},
    );
    // _dialogService.show(DialogRequest(type: DialogType.searchFullscreen));
  }

  Future<void> refreshApiResponse([bool forceLoad = false]) {
    talker.info('[ModernFileManagerController($machineUUID, $filePath)] refreshing api response');
    // ref.invalidate(directoryInfoApiResponseProvider(machineUUID, filePath));
    if (forceLoad) {
      state = state.copyWith(folderContent: const AsyncLoading());
    }

    ref.invalidate(moonrakerFolderContentProvider);
    return ref.refresh(directoryInfoApiResponseProvider(machineUUID, filePath).future);
  }

  void onClickJobQueueFab() {
    ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: ProSheetType.jobQueueMenu));
  }

  Future<void> onClickAddFileFab(Rect origin) async {
    final allowedTypes = _root == 'gcodes'
        ? [...gcodeFileExtensions]
        : [...configFileExtensions, ...textFileExtensions];

    await _handleFileInteractionEventStream(
      _fileInteractionService.showNewFileOptionsMenu(
        filePath,
        origin,
        machineUUID,
        allowedTypes,
        stateOrNull?.folderContent.requireValue.folderFileNames,
      ),
    );
  }

  void onClickCancelUpOrDownload() {
    _downloadToken?.cancel();
    _uploadToken?.cancel();
  }

  //////////////////// SELECTED FILES ////////////////////

  void onClickClearSelection() {
    state = state.copyWith(selectedFiles: []);
  }

  void onClickSelectAll() {
    final files = state.folderContent.requireValue.files;
    state = state.copyWith(selectedFiles: files);
  }

  Future<void> onClickMoveSelected() async {
    final selectedFiles = state.selectedFiles;
    if (selectedFiles.isEmpty) return;
    await _handleFileInteractionEventStream(_fileInteractionService.moveFilesAction(selectedFiles));
    state = state.copyWith(selectedFiles: []);
  }

  Future<void> onClickMoreActionsSelected(Rect pos) async {
    final selectedFiles = state.selectedFiles;
    await _handleFileInteractionEventStream(
      _fileInteractionService.showMultiFileActionMenu(selectedFiles, pos, machineUUID),
    );
  }

  //////////////////// MISC ////////////////////

  Future<void> _handleFileInteractionEventStream(Stream<FileInteractionMenuEvent> stream) async {
    await for (var event in stream) {
      _onFileInteractionMenuEvents(event);
    }
  }

  //////////////////// NOTIFICATIONS ////////////////////

  void _onFileInteractionMenuEvents(FileInteractionMenuEvent event) {
    // talker.warning('[ModernFileManagerController($machineUUID, $filePath)] file interaction menu event: $event');
    switch (event) {
      case FileActionSelected():
        talker.info(
          '[ModernFileManagerController($machineUUID, $filePath)] multi file action selected: ${event.action}',
        );
        break;
      case FileOperationTriggered():
        state = state.copyWith(folderContent: state.folderContent.toLoading(false));
        break;
      case FileTransferOperationProgress(action: FileSheetAction.download) when _downloadToken == null:
        _downloadToken = event.token;
      case FileTransferOperationProgress(action: FileSheetAction.download):
        state = state.copyWith(download: event.event);
        break;
      case FileTransferOperationProgress(action: FileSheetAction.uploadFile) when _uploadToken == null:
        _uploadToken = event.token;
      case FileTransferOperationProgress(action: FileSheetAction.uploadFile):
        state = state.copyWith(upload: event.event);
        break;
      case FileOperationCompleted():
        talker.info('[ModernFileManagerController($machineUUID, $filePath)] file action completed: ${event.action}');
        // it is NOT possible to have an up and download at the same time!
        _downloadToken = null;
        _uploadToken = null;
        state = state.copyWith(download: null, upload: null, selectedFiles: []);
        ref.invalidateSelf();
        break;
      default:
      // Do nothing
    }
  }

  void _onFileNotification(AsyncValue<FileActionResponse>? prev, AsyncValue<FileActionResponse> next) {
    final notification = next.valueOrNull;
    if (notification == null) return;
    if (notification == _lastResponse) return;
    _lastResponse = notification;

    talker.info('[ModernFileManagerController($machineUUID, $filePath)] Got a file notification: $notification');

    final activeViewName = _goRouter.state?.name;
    final activeFileUiExtra = _goRouter.state?.extra;
    final activeFileUiPath = _goRouter.state?.uri.path.substring(7).let(Uri.decodeComponent) ?? filePath;

    if (_goRouter.state?.uri.path.startsWith('/files/') != true) {
      talker.info(
        '[ModernFileManagerController($machineUUID, $filePath)] Ignoring notification, not in file manager view',
      );
      return;
    }

    // Check if the notifications are only related to the current folder
    switch (notification.action) {
      case FileAction.delete_dir when notification.item.fullPath == filePath:
        // This controller code section handles UI navigation when folders are deleted from the file system.
        // It manages two scenarios:
        //
        // 1. DIRECT DELETION: When the currently active folder is deleted
        //    Example: Active path "gcodes/foo" is deleted
        //    Action: Simply pops the current view to return to parent "gcodes/"
        //
        // 2. PARENT DELETION: When a parent folder of the active folder is deleted
        //    Example: Active path is "gcodes/foo/bar/baz" and "gcodes/foo" is deleted
        //    Action only taken by the parent controller, child (baz) does nothing:
        //    - Pops all views from "baz" up to and including the deleted folder "foo"
        //    - Returns to the closest surviving parent ("gcodes/")
        //    - Ensures all affected path references are properly invalidated
        //
        // The controller ensures clean UI state by removing all views that reference
        // now-nonexistent paths in the file system.

        talker.info('''
          [ModernFileManagerController($machineUUID, $filePath)]
            Folder deletion detected:
            - Deleted path: $filePath
            - Currently active folder: $activeFileUiPath
            - Will navigate to surviving parent folder
        ''');

        // Case 1: DIRECT DELETION - Handle deletion of currently active folder
        if (activeFileUiPath == filePath) {
          talker.info('''
            [ModernFileManagerController($machineUUID, $filePath)]
              Direct folder deletion:
              - Closing view for deleted folder: $filePath
              - Returning to parent folder
          ''');

          _goRouter.pop();
          WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidateSelf());
          return;
        }

        // Case 2: PARENT DELETION - Handle deletion of a parent folder
        final activePathSegments = activeFileUiPath.split('/').toList();
        final deletedPathSegments = filePath.split('/').toList();

        // Calculate how many levels need to be popped
        final sharedPathDepth = findCommonPathLength(activePathSegments, deletedPathSegments);
        // We need to pop everything from current path down to parent of deleted folder
        // +1 ensures we also pop the deleted folder's view itself
        final viewsToClose = activePathSegments.length - sharedPathDepth + 1;

        talker.info('''
          [ModernFileManagerController($machineUUID, $filePath)]
            Parent folder deletion detected:
            - Views to close: $viewsToClose
            - Will return to path: ${deletedPathSegments.sublist(0, sharedPathDepth - 1).join('/')}
        ''');

        // Pop views and invalidate references
        for (var i = 0; i < viewsToClose; i++) {
          final currentlyClosingPath = activePathSegments.sublist(0, activePathSegments.length - i).join('/');
          final closingSegment = activePathSegments[activePathSegments.length - 1 - i];

          talker.info(
            '[ModernFileManagerController($machineUUID, $filePath)] Closing view for path segment: $closingSegment, path: $currentlyClosingPath',
          );
          _goRouter.pop();

          if (currentlyClosingPath == filePath) {
            WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidateSelf());
          } else {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => ref.invalidate(_modernFileManagerControllerProvider(machineUUID, currentlyClosingPath)),
            );
          }
        }

        talker.info('''
          [ModernFileManagerController($machineUUID, $filePath)]
            Folder deletion handling completed:
            - Total views closed: $viewsToClose
            - Navigation stack updated
        ''');
        break;
      case FileAction.move_dir when notification.sourceItem?.fullPath == filePath:
        // This controller code section manages UI navigation when folders are moved in the file system.
        // It handles two primary scenarios:
        //
        // 1. DIRECT MOVE: When the active folder itself is moved
        //    Example: Active path "gcodes/foo/bar" is moved to "gcodes/bar"
        //    Action: Closes views for "bar" and "foo", then rebuilds with just the new "bar" location
        //
        // 2. PARENT MOVE: When a parent folder of the active folder is moved
        //    Example: Active path is "gcodes/foo/bar" and "gcodes/foo" is moved to "gcodes/lol/foo"
        //    Action:
        //    - The active child controller ("bar") stays passive
        //    - The parent controller ("foo") handles rebuilding:
        //      a) Pops views back to common root ("gcodes/")
        //      b) Rebuilds full path: "gcodes/lol/" → "gcodes/lol/foo" → "gcodes/lol/foo/bar"
        //
        // The reconstruction process ensures the UI stack accurately reflects the new file system structure
        // while maintaining the user's current view context.

        final movedFolder = Folder.fromFileItem(notification.item);
        // The currently active path in the UI (represents the old location)
        final currentUIPathSegments = activeFileUiPath.split('/').toList();
        // The destination path where the folder was moved to
        final destinationPathSegments = movedFolder.absolutPath.split('/').toList();

        talker.info('''
          [ModernFileManagerController($machineUUID, $filePath)] 
            Folder move detected:
            - From: $filePath
            - To: ${movedFolder.absolutPath}
            - Currently active folder: $activeFileUiPath
        ''');

        // Calculate how much of the path structure needs to change
        final int sharedPathDepth = findCommonPathLength(currentUIPathSegments, destinationPathSegments);
        final viewsToClose = currentUIPathSegments.length - sharedPathDepth;
        final newPathSegmentsToAdd = destinationPathSegments.sublist(sharedPathDepth);

        // Handle the PARENT MOVE scenario
        if (activeFileUiPath != filePath) {
          talker.info('''
            [ModernFileManagerController($machineUUID, $filePath)]
              Parent folder move detected:
              - Active child path will be preserved
              - Will reconstruct path to maintain child view at new location
          ''');

          // Calculate which parts of the active child path need to be preserved
          final parentPathDepth = findCommonPathLength(currentUIPathSegments, filePath.split('/'));
          // Preserve the child-specific path segments to reconstruct at the new location
          final childPathSegments = currentUIPathSegments.sublist(parentPathDepth);
          newPathSegmentsToAdd.addAll(childPathSegments);

          talker.info('''
            [ModernFileManagerController($machineUUID, $filePath)]
              Path reconstruction details:
              - Shared path depth: $sharedPathDepth
              - Views to close: $viewsToClose
              - Child segments to preserve: ${childPathSegments.join('/')}
          ''');
        }

        // Close views back to the common root path
        for (var i = 0; i < viewsToClose; i++) {
          final segmentToClose = currentUIPathSegments[currentUIPathSegments.length - 1 - i];
          final remainingPath = currentUIPathSegments.sublist(0, currentUIPathSegments.length - i).join('/');

          talker.info(
            '[ModernFileManagerController($machineUUID, $filePath)] Closing view for path segment: $segmentToClose',
          );
          _goRouter.pop();

          // Invalidate references only for affected paths
          if (remainingPath == filePath) {
            WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidateSelf());
          } else {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => ref.invalidate(_modernFileManagerControllerProvider(machineUUID, remainingPath)),
            );
          }
        }

        // Rebuild the path with new segments
        String reconstructedPath = destinationPathSegments.sublist(0, sharedPathDepth).join('/');

        // Push new views for each path segment
        for (final pathSegment in newPathSegmentsToAdd) {
          final isLast = pathSegment == newPathSegmentsToAdd.last;

          switch (activeViewName) {
            case String() when !isLast || activeViewName == AppRoute.fileManager_explorer.name:
              reconstructedPath = '$reconstructedPath/$pathSegment';

              talker.info(
                '[ModernFileManagerController($machineUUID, $filePath)] Opening new Folder view for path: $reconstructedPath',
              );

              _goRouter.pushNamed(
                AppRoute.fileManager_explorer.name,
                pathParameters: {'path': reconstructedPath},
                // Only pass the folder object if we're at its exact path
                extra: movedFolder.only(reconstructedPath == movedFolder.absolutPath),
              );
              break;
            case String()
                when activeViewName == AppRoute.fileManager_exlorer_gcodeDetail.name && activeFileUiExtra is GCodeFile:
              talker.info(
                '[ModernFileManagerController($machineUUID, $filePath)] Opening new GCodeDetails view for path: $reconstructedPath',
              );

              _goRouter.pushNamed(
                AppRoute.fileManager_exlorer_gcodeDetail.name,
                pathParameters: {'path': reconstructedPath},
                extra: activeFileUiExtra.copyWith(parentPath: reconstructedPath),
              );
              break;
            case String() when activeFileUiExtra is GenericFile:
              talker.info(
                '[ModernFileManagerController($machineUUID, $filePath)] Opening new $activeViewName view for path: $reconstructedPath',
              );

              _goRouter.pushNamed(
                activeViewName,
                pathParameters: {'path': reconstructedPath},
                extra: activeFileUiExtra.copyWith(parentPath: reconstructedPath),
              );
              break;
            default:
          }
        }

        talker.info('''
          [ModernFileManagerController($machineUUID, $filePath)]
            Path reconstruction completed:
            - Final path: $reconstructedPath
            - Total views modified: ${viewsToClose + newPathSegmentsToAdd.length}
        ''');
      default:
        // Do Nothing!
        break;
    }
  }

  void _onJrpcStateNotification(AsyncValue<ClientState>? prev, AsyncValue<ClientState> next) {
    var nextState = next.valueOrNull;
    if (nextState == null) return;

    if (nextState != ClientState.connected) {
      talker.info(
        '[ModernFileManagerController($machineUUID, $filePath)] Client disconnected, will exist selection mode',
      );
      state = state.copyWith(selectedFiles: []);
    }
  }

  void _onModelChanged(_Model? prev, _Model next) {
    if (!next.hasTimelapseComponent && filePath.startsWith('timelapse')) {
      talker.info(
        '[ModernFileManagerController($machineUUID, $filePath)] Timelapse component was removed/not available anymore, will move to gcodes',
      );
      _goRouter.replaceNamed(AppRoute.fileManager_explorer.name, pathParameters: {'path': 'gcodes'});
    }
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required AsyncValue<FolderContentWrapper> folderContent,
    required SortConfiguration sortConfiguration,
    FileOperation? download,
    FileOperation? upload,
    @Default([]) List<RemoteFile> selectedFiles,
    @Default(false) bool hasTimelapseComponent,
  }) = __Model;

  bool get selectionMode => selectedFiles.isNotEmpty;

  bool get isUploading => upload != null;

  bool get isDownloading => download != null;

  bool get isOperationActive => isUploading || isDownloading;
}
