/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/moonraker/file_action_response.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/enums/file_action_enum.dart';
import 'package:common/data/enums/file_action_sheet_action_enum.dart';
import 'package:common/data/enums/gcode_file_action_sheet_action_enum.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/exceptions/file_fetch_exception.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/src/cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg/svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker/ui/components/job_queue_fab.dart';
import 'package:mobileraker/ui/screens/files/components/remote_file_list_tile.dart';
import 'package:mobileraker_pro/service/moonraker/job_queue_service.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:persistent_header_adaptive/persistent_header_adaptive.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:stringr/stringr.dart';

import '../../../routing/app_router.dart';
import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../../service/ui/dialog_service_impl.dart';
import '../../components/bottomsheet/action_bottom_sheet.dart';
import '../../components/connection/machine_connection_guard.dart';
import '../../components/dialog/text_input/text_input_dialog.dart';
import 'components/remote_file_icon.dart';
import 'components/sorted_file_list_header.dart';

part 'file_manager_page.freezed.dart';

part 'file_manager_page.g.dart';

class FileManagerPage extends ConsumerWidget {
  const FileManagerPage({super.key, required this.filePath, this.folder});

  final String filePath;
  final Folder? folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = MachineConnectionGuard(
        onConnected: (ctx, machineUUID) => _ManagerBody(machineUUID: machineUUID, filePath: filePath));
    final fab = _Fab(filePath: filePath);
    if (context.isLargerThanCompact) {
      body = NavigationRailView(leading: fab, page: body);
    }

    return Scaffold(
      appBar: _AppBar(filePath: filePath, folder: folder),
      drawer: const NavigationDrawerWidget().unless(filePath.split('/').length > 1),
      bottomNavigationBar: _BottomNav(filePath: filePath).unless(context.isLargerThanCompact),
      floatingActionButton: fab.unless(context.isLargerThanCompact),
      body: body,
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
    final themeData = Theme.of(context);

    final actions = (selMachine == null)
        ? <Widget>[]
        : [
            Consumer(builder: (context, ref, _) {
              final controller = ref.watch(_modernFileManagerControllerProvider(selMachine.uuid, filePath).notifier);

              return IconButton(
                tooltip: tr('pages.files.search_files'),
                icon: const Icon(Icons.search),
                onPressed: controller.onSearch,
              );
            }),
            if (folder != null && !isRoot)
              Consumer(builder: (context, ref, _) {
                final controller = ref.watch(_modernFileManagerControllerProvider(selMachine.uuid, filePath).notifier);

                return IconButton(
                  tooltip: tr('pages.files.search_files'),
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    final box = context.findRenderObject() as RenderBox?;
                    final pos = box!.localToGlobal(Offset.zero) & box.size;

                    controller.onClickFileAction(folder!, pos);
                  },
                );
              }),
          ];

    if (isRoot) {
      return SwitchPrinterAppBar(
        centerTitle: themeData.platform == TargetPlatform.iOS || themeData.platform == TargetPlatform.macOS,
        title: title.capitalize(),
        actions: actions,
      );
    }

    return AppBar(title: Text(title.capitalize()), actions: actions);
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _Fab extends ConsumerWidget {
  const _Fab({super.key, required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMachine = ref.watch(selectedMachineProvider).valueOrNull;

    if (selectedMachine == null) {
      return const SizedBox.shrink();
    }

    final controller = ref.watch(_modernFileManagerControllerProvider(selectedMachine.uuid, filePath).notifier);
    final (isDownloading, isUploading, isFilesLoading, isSelecting) =
        ref.watch(_modernFileManagerControllerProvider(selectedMachine.uuid, filePath).select((data) {
      return (data.download != null, data.upload != null, data.folderContent.isLoading, data.selectionMode);
    }));
    final connected =
        ref.watch(jrpcClientStateProvider(selectedMachine.uuid).select((d) => d.valueOrNull == ClientState.connected));
    final isUpOrDownloading = isDownloading || isUploading;

    if (!connected || filePath == 'timelapse' || isSelecting) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (filePath == 'gcodes') ...[
          AnimatedSwitcher(
            duration: kThemeAnimationDuration,
            switchInCurve: Curves.easeInOutCubicEmphasized,
            switchOutCurve: Curves.easeInOutCubicEmphasized,
            // duration: kThemeAnimationDuration,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: JobQueueFab(
              machineUUID: selectedMachine.uuid,
              onPressed: controller.onJobQueueFab,
              mini: true,
              hideIfEmpty: true,
            ),
          ),
          const Gap(4),
        ],
        if (!isUpOrDownloading)
          FloatingActionButton(
            heroTag: '${selectedMachine.uuid}-main',
            onPressed: controller.onAddFile.only(!isFilesLoading),
            child: const Icon(Icons.add),
          ),
        if (isUpOrDownloading)
          FloatingActionButton.extended(
            heroTag: '${selectedMachine.uuid}-main',
            onPressed: controller.onCancelUpOrDownload,
            label: const Text('pages.files.cancel_fab').tr(gender: isUploading ? 'upload' : 'download'),
          ),
      ],
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

    final connected =
        ref.watch(jrpcClientStateProvider(selectedMachine.uuid).select((d) => d.valueOrNull == ClientState.connected));
    if (!connected) {
      return const SizedBox.shrink();
    }

    final controller = ref.watch(_modernFileManagerControllerProvider(selectedMachine.uuid, filePath).notifier);

    final inSelectionMode = ref.watch(
        _modernFileManagerControllerProvider(selectedMachine.uuid, filePath).select((data) => data.selectionMode));

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
      onTap: controller.onBottomItemTapped,
      items: [
        BottomNavigationBarItem(
          label: tr('pages.files.gcode_tab'),
          icon: const Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
        ),
        BottomNavigationBarItem(
          label: tr('pages.files.config_tab'),
          icon: const Icon(FlutterIcons.file_code_faw5),
        ),
        if (ref
                .watch(klipperProvider(selectedMachine.uuid).selectAs((data) => data.hasTimelapseComponent))
                .valueOrNull ==
            true)
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

class _ManagerBody extends ConsumerWidget {
  const _ManagerBody({super.key, required this.machineUUID, required this.filePath});

  final String machineUUID;

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _FileList(machineUUID: machineUUID, filePath: filePath)),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({super.key, required this.machineUUID, required this.filePath});

  final String machineUUID;

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_modernFileManagerControllerProvider(machineUUID, filePath).notifier);
    final (sortCfg, apiLoading) = ref.watch(_modernFileManagerControllerProvider(machineUUID, filePath)
        .select((data) => (data.sortConfiguration, data.folderContent.isLoading)));

    final themeData = Theme.of(context);

    return SortedFileListHeader(
      activeSortConfig: sortCfg,
      onTapSortMode: controller.onSortMode.only(!apiLoading),
      trailing: IconButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // 12 is basis vom icon button + 4 weil list tile hat 14 padding + 1 wegen size 22
        onPressed: controller.onCreateFolder.only(!apiLoading),
        icon: Icon(Icons.create_new_folder, size: 22, color: themeData.textTheme.bodySmall?.color),
      ),
    );
  }
}

class _FileListLoading extends StatelessWidget {
  const _FileListLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: Colors.grey,
      highlightColor: themeData.colorScheme.background,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 20,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.white),
                      ),
                    ),
                    Spacer(),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverList.separated(
            separatorBuilder: (context, index) => const Divider(
              height: 0,
              indent: 18,
              endIndent: 18,
            ),
            itemCount: 20,
            itemBuilder: (context, index) {
              return const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
                horizontalTitleGap: 8,
                leading: SizedBox(
                  width: 42,
                  height: 42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.red),
                  ),
                ),
                trailing: Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.white),
                    ),
                  ),
                ),
                title: FractionallySizedBox(
                  alignment: Alignment.bottomLeft,
                  widthFactor: 0.7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white),
                    child: Text(' '),
                  ),
                ),
                dense: true,
                subtitle: FractionallySizedBox(
                  alignment: Alignment.bottomLeft,
                  widthFactor: 0.42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white),
                    child: Text(' '),
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
          Text(
            'The following error occued while trying to fetch files:n$error',
          ),
          TextButton(
            // onPressed: model.showPrinterFetchingErrorDialog,
            onPressed: () => ref.read(dialogServiceProvider).show(DialogRequest(
                  type: CommonDialogs.stacktrace,
                  title: error.runtimeType.toString(),
                  body: 'Exception:\n$error\n\n$stack',
                )),
            child: const Text('Show Full Error'),
          ),
        ],
      ),
    );
  }
}

class _FileList extends ConsumerStatefulWidget {
  const _FileList({super.key, required this.machineUUID, required this.filePath});

  final String machineUUID;

  final String filePath;

  @override
  ConsumerState createState() => _FileListState();
}

class _FileListState extends ConsumerState<_FileList> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

  ValueNotifier<bool> _isUserRefresh = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMd(context.deviceLocale.languageCode));

    final controller = ref.watch(_modernFileManagerControllerProvider(widget.machineUUID, widget.filePath).notifier);

    final (folderContent, sortConfiguration) = ref.watch(
        _modernFileManagerControllerProvider(widget.machineUUID, widget.filePath)
            .select((data) => (data.folderContent, data.sortConfiguration)));
    final themeData = Theme.of(context);

    return AsyncValueWidget(
      debugLabel: 'ModernFileManager._FileListState(${widget.machineUUID}, ${widget.filePath})',
      value: folderContent,
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      loading: () => const _FileListLoading(),
      data: (data) {
        final content = data.unwrapped;

        if (content.isEmpty) {
          final themeData = Theme.of(context);

          return Column(
            children: [
              SortedFileListHeader(
                activeSortConfig: null,
                trailing: IconButton(
                  padding: const EdgeInsets.only(right: 12),
                  // 12 is basis vom icon button + 4 weil list tile hat 14 padding + 1 wegen size 22
                  onPressed: controller.onCreateFolder.only(!folderContent.isLoading),
                  icon: Icon(Icons.create_new_folder, size: 22, color: themeData.textTheme.bodySmall?.color),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
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
              ),
            ],
          );
        }

        // Note Wrapping the listview in the SmartRefresher causes the UI to "Lag" because it renders the entire listview at once rather than making use of the builder???
        return SmartRefresher(
          // header: const WaterDropMaterialHeader(),
          header: ClassicHeader(
            textStyle: TextStyle(color: themeData.colorScheme.onBackground),
            completeIcon: Icon(Icons.done, color: themeData.colorScheme.onBackground),
            releaseIcon: Icon(
              Icons.refresh,
              color: themeData.colorScheme.onBackground,
            ),
          ),
          controller: _refreshController,
          onRefresh: () {
            _isUserRefresh.value = true;
            controller.refreshApiResponse().then(
              (_) {
                _refreshController.refreshCompleted();
              },
              onError: (e, s) {
                logger.e(e, s);
                _refreshController.refreshFailed();
              },
            ).whenComplete(() => _isUserRefresh.value = false);
          },
          child: CustomScrollView(
            key: PageStorageKey('${widget.filePath}:${sortConfiguration.mode}:${sortConfiguration.kind}'),
            slivers: [
              AdaptiveHeightSliverPersistentHeader(
                floating: true,
                initialHeight: 48,
                needRepaint: true,
                child: _Header(machineUUID: widget.machineUUID, filePath: widget.filePath),
              ),
              AdaptiveHeightSliverPersistentHeader(
                initialHeight: 4,
                pinned: true,
                child: _LoadingIndicator(
                    machineUUID: widget.machineUUID, filePath: widget.filePath, isUserRefresh: _isUserRefresh),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: kFloatingActionButtonMargin * 2 + 48),
                sliver: SliverList.separated(
                  separatorBuilder: (context, index) => const Divider(
                    height: 0,
                    indent: 18,
                    endIndent: 18,
                  ),
                  itemCount: content.length,
                  itemBuilder: (context, index) {
                    final file = content[index];
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
      },
      error: (e, s) => _FileListError(
        machineUUID: widget.machineUUID,
        filePath: widget.filePath,
        error: e,
        stack: s,
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
      _Model(upload: FileOperationProgress(:final progress)) =>
        progress,
      _Model(folderContent: AsyncValue(isLoading: true)) ||
      _Model(download: FileOperationKeepAlive()) when !wasUser =>
        null,
      _ => 0,
    };
    return LinearProgressIndicator(
      backgroundColor: Colors.transparent,
      value: value,
    );
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
        _modernFileManagerControllerProvider(machineUUID, file.parentPath)
            .select((d) => (d.selectedFiles.contains(file), d.selectionMode, d.folderContent.isLoading == false)));

    var numberFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);

    Widget subtitle = switch (sortMode) {
      SortMode.size => Text(numberFormat.formatFileSize(file.size)),
      SortMode.lastPrinted when file is GCodeFile =>
        Text((file as GCodeFile).lastPrintDate?.let(dateFormat.format) ?? '--'),
      SortMode.lastPrinted => const Text('--'),
      SortMode.lastModified => Text(file.modifiedDate?.let(dateFormat.format) ?? '--'),
      _ => Text('@:pages.files.sort_by.last_modified: ${file.modifiedDate?.let(dateFormat.format) ?? '--'}').tr(),
    };

    return RemoteFileListTile(
        machineUUID: machineUUID,
        file: file,
        selected: selected,
        subtitle: subtitle,
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
            controller.onClickFile(file);
          }
        }.only(enabled),
        onLongPress: () {
          controller.onLongClickFile(file);
        }.only(enabled));
  }

  Widget buildLeading(
    Uri imageUri,
    Map<String, String> headers,
    CacheManager cacheManager,
  ) {
    return CachedNetworkImage(
      cacheManager: cacheManager,
      cacheKey: '${imageUri.hashCode}-${file.hashCode}',
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      ),
      imageUrl: imageUri.toString(),
      httpHeaders: headers,
      placeholder: (context, url) => const Icon(Icons.image),
      errorWidget: (context, url, error) {
        logger.w(url);
        logger.e(error);
        return const Icon(Icons.error);
      },
    );
  }
}

@riverpod
class _ModernFileManagerController extends _$ModernFileManagerController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  SettingService get _settingService => ref.read(settingServiceProvider);

  FileService get _fileService => ref.read(fileServiceProvider(machineUUID));

  JobQueueService get _jobQueueService => ref.read(jobQueueServiceProvider(machineUUID));

  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  // ignore: avoid-unsafe-collection-methods
  String get _root => filePath.split('/').first;

  String get _relativeToRoot => filePath.split('/').skip(1).join('/');

  List<SortMode> get _availableSortModes => switch (_root) {
        'gcodes' => [SortMode.name, SortMode.lastModified, SortMode.lastPrinted, SortMode.size],
        _ => [SortMode.name, SortMode.lastModified, SortMode.size],
      };

  CompositeKey get _sortModeKey => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, 'mode:$_root');

  CompositeKey get _sortKindKey => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, 'kind:$_root');

  CancelToken? _downloadToken;
  CancelToken? _uploadToken;

  @override
  _Model build(String machineUUID, [String filePath = 'gcodes']) {
    ref.keepAliveFor();
    ref.listen(fileNotificationsProvider(machineUUID, filePath),
        (prev, next) => next.whenData((notification) => _onFileNotification(notification)));

    logger.i('[ModernFileManagerController($machineUUID, $filePath)] fetching directory info for $filePath');

    final supportedModes = _availableSortModes;
    final sortModeIdx = ref.watch(intSettingProvider(_sortModeKey)).clamp(0, supportedModes.length - 1);
    final sortKindIdx = ref.watch(intSettingProvider(_sortKindKey)).clamp(0, SortKind.values.length - 1);

    // ignore: avoid-unsafe-collection-methods
    final sortConfiguration = SortConfiguration(supportedModes[sortModeIdx], SortKind.values[sortKindIdx]);

    var apiResp = ref.watch(moonrakerFolderContentProvider(machineUUID, filePath, sortConfiguration));

    logger.i('[ModernFileManagerController($machineUUID, $filePath)] The api response is: $apiResp ');
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] and the current state is: $stateOrNull');

    // Required to get a smoother UX and to prevent the folder content from beeing empty!
    if (stateOrNull != null) {
      apiResp = apiResp.copyWithPrevious(stateOrNull!.folderContent, isRefresh: apiResp.isRefreshing);
    }

    return _Model(
      folderContent: apiResp,
      sortConfiguration: sortConfiguration,
      download: stateOrNull?.download,
      upload: stateOrNull?.upload,
    );
  }

  void onClickFile(RemoteFile file) {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] opening file ${file.name} (${file.runtimeType})');

    switch (file) {
      case GCodeFile():
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_gcodeDetail.name,
            pathParameters: {'path': filePath}, extra: file);
        break;
      case Folder():
        _goRouter.pushNamed(AppRoute.fileManager_explorer.name,
            pathParameters: {'path': file.absolutPath}, extra: file);
        break;
      case RemoteFile(isVideo: true):
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_videoPlayer.name,
            pathParameters: {'path': filePath}, extra: file);
        break;
      case RemoteFile(isImage: true):
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_imageViewer.name,
            pathParameters: {'path': filePath}, extra: file);
        break;
      default:
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_editor.name, pathParameters: {'path': filePath}, extra: file);
    }
  }

  void onLongClickFile(RemoteFile file) {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] file longPress: ${file.name}');
    // _goRouter.pushNamed(AppRoute.fileManager_explorer.name, pathParameters: {'path': file.absolutPath});

    // if not in selected, add
    if (!state.selectedFiles.contains(file)) {
      state = state.copyWith(selectedFiles: [...state.selectedFiles, file]);
    } else {
      // if in selected, remove
      state = state.copyWith(selectedFiles: state.selectedFiles.where((it) => it != file).toList());
    }
  }

  void onClickFileAction(RemoteFile file, Rect origin) async {
    final klippyReady = ref.read(klipperProvider(machineUUID)).valueOrNull?.klippyCanReceiveCommands == true;
    final canStartPrint = ref
        .read(printerProvider(machineUUID))
        .valueOrNull
        // .also((d) => logger.w('State: ${d?.print.state}'))
        .let((d) => d != null && (d.print.state != PrintState.printing && d.print.state != PrintState.paused));

    // logger.w('Klipper ready: $klippyReady, can start print: $canStartPrint');

    final arg = ActionBottomSheetArgs(
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: file.fileExtension?.let((ext) => Text(ext.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis)),
      leading: SizedBox.square(
        dimension: 33,
        child: RemoteFileIcon(
          machineUUID: machineUUID,
          file: file,
          alignment: Alignment.centerLeft,
          imageBuilder: (BuildContext context, ImageProvider imageProvider) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(7)),
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
            );
          },
        ),
      ),
      actions: [
        if (file case GCodeFile()) ...[
          GcodeFileSheetAction.submitPrintJob.let((t) => canStartPrint && klippyReady ? t : t.disable),
          GcodeFileSheetAction.preheat
              .let((t) => file.firstLayerTempBed != null && canStartPrint && klippyReady ? t : t.disable),
          GcodeFileSheetAction.addToQueue,
          DividerSheetAction.divider,
        ],
        if (file is! Folder) ...[
          FileSheetAction.download,
          DividerSheetAction.divider,
        ],
        FileSheetAction.rename,
        FileSheetAction.copy,
        FileSheetAction.move,
        FileSheetAction.delete,
      ],
    );

    final resp =
        await _bottomSheetService.show(BottomSheetConfig(type: SheetType.actions, isScrollControlled: true, data: arg));
    if (resp.confirmed) {
      logger.i('[ModernFileManagerController($machineUUID, $filePath)] action confirmed: ${resp.data}');

      // Wait for the bottom sheet to close
      await Future.delayed(kThemeAnimationDuration);

      switch (resp.data) {
        case FileSheetAction.delete:
          _deleteFileAction(file);
          break;
        case FileSheetAction.rename:
          _renameFileAction(file);
          break;
        case GcodeFileSheetAction.addToQueue:
          _addToQueueAction(file as GCodeFile);
          break;
        case GcodeFileSheetAction.preheat when file is GCodeFile:
          _preheatAction(file);
          break;
        case GcodeFileSheetAction.submitPrintJob when file is GCodeFile:
          _submitJobAction(file);
          break;
        case FileSheetAction.download:
          _downloadFileAction(file, origin);
          break;
        case FileSheetAction.move:
          _moveFileAction(file);
        case FileSheetAction.copy:
          _copyFileAction(file);
          break;
        default:
          logger.w('Action not implemented: $resp');
      }
    }
  }

  void onBottomItemTapped(int index) {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] bottom nav item tapped: $index');

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

  void onCreateFolder() async {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] creating folder');

    final usedNames = state.folderContent.requireValue.folderFileNames;

    var dialogResponse = await _dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        title: tr('dialogs.create_folder.title'),
        actionLabel: tr('general.create'),
        data: TextInputDialogArguments(
          initialValue: '',
          labelText: tr('dialogs.create_folder.label'),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.match(
              r'^\w?[\w .-]*[\w-]$',
              errorText: tr('pages.files.no_matches_file_pattern'),
            ),
            notContains(
              usedNames,
              errorText: tr('form_validators.file_name_in_use'),
            ),
          ]),
        ),
      ),
    );

    if (dialogResponse?.confirmed == true) {
      String newName = dialogResponse!.data;

      state = state.copyWith(folderContent: state.folderContent.toLoading(false));
      _fileService.createDir('$filePath/$newName').ignore();
    }
  }

  Future<void> onSortMode() async {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] sort mode');
    final args = SortModeSheetArgs(
      toShow: _availableSortModes,
      active: state.sortConfiguration,
    );

    final res = await _bottomSheetService.show(BottomSheetConfig(type: SheetType.sortMode, data: args));

    if (res.confirmed == true) {
      logger.i('SortModeSheet confirmed: ${res.data}');

      // This is required to already show the new sort mode before the data is updated
      state = state.copyWith(sortConfiguration: res.data);
      // This will trigger a rebuild!
      _settingService.writeInt(_sortModeKey, res.data.mode.index);
      _settingService.writeInt(_sortKindKey, res.data.kind.index);
    }
  }

  void onSearch() {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] search');

    _goRouter.pushNamed(AppRoute.fileManager_exlorer_search.name,
        pathParameters: {'path': filePath}, queryParameters: {'machineUUID': machineUUID});
    // _dialogService.show(DialogRequest(type: DialogType.searchFullscreen));
  }

  Future<void> refreshApiResponse([bool forceLoad = false]) {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] refreshing api response');
    // ref.invalidate(fileApiResponseProvider(machineUUID, filePath));
    if (forceLoad) {
      state = state.copyWith(folderContent: const AsyncLoading());
    }

    ref.invalidate(moonrakerFolderContentProvider);
    return ref.refresh(fileApiResponseProvider(machineUUID, filePath).future);
  }

  void onJobQueueFab() {
    ref
        .read(bottomSheetServiceProvider)
        .show(BottomSheetConfig(type: ProSheetType.jobQueueMenu, isScrollControlled: true));
  }

  Future<void> onAddFile() async {
    const args = ActionBottomSheetArgs(actions: [
      FileSheetAction.newFolder,
      FileSheetAction.newFile,
      DividerSheetAction.divider,
      FileSheetAction.uploadFile,
      FileSheetAction.uploadFiles,
    ]);

    final res = await ref
        .read(bottomSheetServiceProvider)
        .show(BottomSheetConfig(type: SheetType.actions, isScrollControlled: true, data: args));

    if (res.confirmed != true) return;
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] create-action confirmed: ${res.data}');
    // Wait for the bottom sheet to close
    await Future.delayed(kThemeAnimationDuration);
    switch (res.data) {
      case FileSheetAction.newFolder:
        onCreateFolder();
        break;

      case FileSheetAction.uploadFiles:
      case FileSheetAction.uploadFile:
        final allowed = _root == 'gcodes' ? [...gcodeFileExtensions] : [...configFileExtensions, ...textFileExtensions];

        _uploadFile(allowed, res.data == FileSheetAction.uploadFiles);
        break;
      case FileSheetAction.newFile:
        _newFile();
        break;

      default:
    }
  }

  void onCancelUpOrDownload() {
    _downloadToken?.cancel();
    _uploadToken?.cancel();
  }

  //////////////////// ACTIONS ////////////////////
  Future<void> _deleteFileAction(RemoteFile file) async {
    var dialogResponse = await _dialogService.showConfirm(
      title: tr('dialogs.delete_folder.title'),
      body: tr(
        file is Folder ? 'dialogs.delete_folder.description' : 'dialogs.delete_file.description',
        args: [file.name],
      ),
      actionLabel: tr('general.delete'),
    );

    if (dialogResponse?.confirmed == true) {
      // state = FilePageState.loading(state.path);

      try {
        state = state.copyWith(folderContent: state.folderContent.toLoading(false));
        if (file is Folder) {
          await _fileService.deleteDirForced(file.absolutPath);
        } else {
          await _fileService.deleteFile(file.absolutPath);
        }
      } on JRpcError catch (e) {
        _snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          message: 'Could not delete File.\n${e.message}',
        ));
      }
    }
  }

  Future<void> _renameFileAction(RemoteFile file) async {
    var fileNames = state.folderContent.requireValue.folderFileNames;
    fileNames.remove(file.name);

    var dialogResponse = await _dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        title: file is Folder ? tr('dialogs.rename_folder.title') : tr('dialogs.rename_file.title'),
        actionLabel: tr('general.rename'),
        data: TextInputDialogArguments(
          initialValue: file.fileName,
          labelText: file is Folder ? tr('dialogs.rename_folder.label') : tr('dialogs.rename_file.label'),
          suffixText: file.fileExtension?.let((it) => '.$it'),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.match(
              r'^\w?[\w .-]*[\w-]$',
              errorText: tr('pages.files.no_matches_file_pattern'),
            ),
            notContains(
              fileNames,
              errorText: tr('pages.files.file_name_in_use'),
            ),
          ]),
        ),
      ),
    );

    if (dialogResponse?.confirmed == true) {
      String newName = dialogResponse!.data;
      if (file.fileExtension != null) newName = '$newName.${file.fileExtension!}';
      if (newName == file.name) return;

      try {
        state = state.copyWith(folderContent: state.folderContent.toLoading(false));
        await _fileService.moveFile(
          file.absolutPath,
          '${file.parentPath}/$newName',
        );
      } on JRpcError catch (e) {
        logger.e('Could not perform rename.', e);
        _snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          message: 'Could not rename File.\n${e.message}',
        ));
      }
    }
  }

  Future<void> _moveFileAction(RemoteFile file) async {
    // await _printerService.startPrintFile(file);
    final res = await _goRouter.pushNamed(
      AppRoute.fileManager_exlorer_move.name,
      pathParameters: {'path': filePath.split('/').first},
      queryParameters: {'machineUUID': machineUUID, 'submitLabel': tr('pages.files.move_here')},
    );

    if (res case String()) {
      if (file.parentPath == res) return;
      logger.i('[ModernFileManagerController($machineUUID, $filePath)] moving file ${file.name} to $res');
      state = state.copyWith(folderContent: state.folderContent.toLoading(true));
      _fileService.moveFile(file.absolutPath, res).ignore();
    }
  }

  Future<void> _copyFileAction(RemoteFile file) async {
    // First name of the new copy
    var dialogResponse = await _dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        title: file is Folder ? tr('dialogs.copy_folder.title') : tr('dialogs.copy_file.title'),
        actionLabel: tr('pages.files.file_actions.copy'),
        data: TextInputDialogArguments(
          initialValue: '${file.fileName}_copy${file.fileExtension?.let((it) => '.$it') ?? ''}',
          labelText: file is Folder ? tr('dialogs.copy_file.label') : tr('dialogs.copy_file.label'),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.match(
              r'^\w?[\w .-]*[\w-]$',
              errorText: tr('pages.files.no_matches_file_pattern'),
            ),
            notContains(
              state.folderContent.requireValue.folderFileNames,
              errorText: tr('pages.files.file_name_in_use'),
            ),
          ]),
        ),
      ),
    );

    if (dialogResponse?.confirmed == false) return;
    final copyName = dialogResponse!.data;

    final res = await _goRouter.pushNamed(
      AppRoute.fileManager_exlorer_move.name,
      pathParameters: {'path': filePath.split('/').first},
      queryParameters: {'machineUUID': machineUUID, 'submitLabel': tr('pages.files.copy_here')},
    );

    if (res case String()) {
      final copyPath = '$res/$copyName';
      logger
          .i('[ModernFileManagerController($machineUUID, $filePath)] creating copy of file ${file.name} at $copyPath');
      await _fileService.copyFile(file.absolutPath, copyPath);
      _snackBarService.show(SnackBarConfig(
        title: tr('pages.files.file_operation.copy_created.title'),
        message: tr('pages.files.file_operation.copy_created.body', args: [copyPath]),
      ));
    }
  }

  Future<void> _addToQueueAction(GCodeFile file) async {
    final isSup = await ref.read(isSupporterAsyncProvider.future);
    if (!isSup) {
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.warning,
        title: tr('components.supporter_only_feature.dialog_title'),
        message: tr('components.supporter_only_feature.job_queue'),
        duration: const Duration(seconds: 5),
      ));
      return;
    }

    try {
      await _jobQueueService.enqueueJob(file.pathForPrint);
    } on JRpcError catch (e) {
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        message: 'Could not add File to Queue.\n${e.message}',
      ));
    }
  }

  Future<void> _preheatAction(GCodeFile file) async {
    final tempArgs = [
      '170',
      file.firstLayerTempBed?.toStringAsFixed(0) ?? '60',
    ];
    final resp = await _dialogService.showConfirm(
      title: 'pages.files.details.preheat_dialog.title'.tr(),
      body: tr('pages.files.details.preheat_dialog.body', args: tempArgs),
      actionLabel: 'pages.files.details.preheat'.tr(),
    );
    if (resp?.confirmed != true) return;
    _printerService.setHeaterTemperature('extruder', 170);
    if (ref.read(printerSelectedProvider.selectAs((data) => data.heaterBed != null)).valueOrFullNull ?? false) {
      _printerService.setHeaterTemperature(
        'heater_bed',
        (file.firstLayerTempBed ?? 60.0).toInt(),
      );
    }
    _snackBarService.show(SnackBarConfig(
      title: tr('pages.files.details.preheat_snackbar.title'),
      message: tr(
        'pages.files.details.preheat_snackbar.body',
        args: tempArgs,
      ),
    ));
  }

  Future<void> _submitJobAction(GCodeFile file) async {
    await _printerService.startPrintFile(file);
    _goRouter.goNamed(AppRoute.dashBoard.name);
  }

  Future<void> _downloadFileAction(RemoteFile file, Rect origin) async {
    if (file case Folder()) {
      //TODO: ZIP the folder first automatically!
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: 'Error',
        message: 'Cannot share folders. Please ZIP the folder first.',
      ));
      return;
    }
    // await _printerService.startPrintFile(file);
    // _goRouter.goNamed(AppRoute.dashBoard.name);

    bool setToken = false;
    try {
      final downloadStream = _fileService.downloadFile(filePath: file.absolutPath).distinct((a, b) {
        // If both are Download Progress, only update in 0.01 steps:
        const epsilon = 0.01;
        if (a is FileOperationProgress && b is FileOperationProgress) {
          return (b.progress - a.progress) < epsilon;
        }

        return a == b;
      });

      ref.onCancel(() => _downloadToken?.cancel());
      await for (var download in downloadStream) {
        if (!setToken) _downloadToken = download.token;
        state = state.copyWith(download: download);
      }

      if (state.download is FileOperationCanceled) {
        _onOperationCanceled(false);
        return;
      }

      final downloadedFilePath = (state.download as FileDownloadComplete).file.path;

      String mimeType = switch (file.fileExtension) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'jpg' || 'jpeg' => 'image/jpeg',
        'mp4' => 'video/mp4',
        _ => 'text/plain',
      };

      await Share.shareXFiles(
        [XFile(downloadedFilePath, mimeType: mimeType)],
        subject: file.name,
        sharePositionOrigin: origin,
      ).catchError((_) => null);
    } catch (e, s) {
      _onOperationError(e, s, false);
    } finally {
      state = state.copyWith(download: null);
    }
  }

  Future<void> _uploadFile(List<String> allowed, [bool multiple = false]) async {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] uploading file. Allowed: $allowed');

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: kDebugMode ? FileType.any : FileType.custom,
      allowedExtensions: allowed.unless(kDebugMode),
      withReadStream: true,
      allowMultiple: multiple,
      withData: false,
    );

    logger.i('[ModernFileManagerController($machineUUID, $filePath)] FilePicker result: $result');
    if (result == null || result.count == 0) return;
    for (var toUpload in result.files) {
      logger.i('[ModernFileManagerController($machineUUID, $filePath)] Selected file: ${toUpload.name}');

      final mPrt = MultipartFile.fromStream(() => toUpload.readStream!, toUpload.size,
          filename: '$_relativeToRoot/${toUpload.name}');

      final wasSuccessful = await _handleFileUpload(filePath, mPrt);
      if (!wasSuccessful) return;
    }
  }

  Future<void> _newFile() async {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] creating new file');

    // final allowedExtensions = _root == 'gcodes' ? [...gcodeFileExtensions] : [...configFileExtensions, ...textFileExtensions];

    final res = await _dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        title: tr('dialogs.create_file.title'),
        actionLabel: tr('general.create'),
        data: TextInputDialogArguments(
          initialValue: '',
          labelText: tr('dialogs.create_file.label'),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.match(
              r'^\w?[\w .-]*[\w-]$',
              errorText: tr('pages.files.no_matches_file_pattern'),
            ),
            notContains(
              state.folderContent.requireValue.folderFileNames,
              errorText: tr('pages.files.file_name_in_use'),
            ),
          ]),
        ),
      ),
    );

    if (res?.confirmed != true) return;
    final fileName = res!.data;
    final multipartFile = MultipartFile.fromString('', filename: '$_relativeToRoot/$fileName');

    await _handleFileUpload(filePath, multipartFile);
  }

  Future<bool> _handleFileUpload(String path, MultipartFile toUpload) async {
    try {
      final uploadStream = _fileService.uploadFile(path, toUpload);

      bool setToken = false;
      ref.onCancel(() => _uploadToken?.cancel());
      await for (var update in uploadStream) {
        if (!setToken) _uploadToken = update.token;
        state = state.copyWith(upload: update);
      }

      if (state.upload is FileOperationCanceled) {
        _onOperationCanceled(true);
        return false;
      }

      logger.i('[ModernFileManagerController($machineUUID, $filePath)] File uploaded');

      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.files.file_operation.upload_success.title'),
        message: tr('pages.files.file_operation.upload_success.body'),
      ));
    } catch (e, s) {
      logger.e('Could not upload file.', e, s);
      _onOperationError(e, s, true);
      return false;
    } finally {
      state = state.copyWith(upload: null);
    }
    return true;
  }

  //////////////////// NOTIFICATIONS ////////////////////

  void _onFileNotification(FileActionResponse notification) {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] Got a file notification: $notification');

    // Check if the notifications are only related to the current folder

    switch (notification.action) {
      case FileAction.delete_dir when notification.item.fullPath == filePath:
        logger.i('[ModernFileManagerController($machineUUID, $filePath)] Folder was deleted, will move to parent');
        _goRouter.pop();
        ref.invalidateSelf();
        break;
      case FileAction.move_dir when notification.sourceItem?.fullPath == filePath:
        final folder = Folder.fromFileItem(notification.item);
        logger.i('[ModernFileManagerController($machineUUID, $filePath)] Folder was moved to ${folder.absolutPath}');
        // _goRouter.pushReplacement(notification.item.fullPath, extra: folder);
        _goRouter.pushReplacementNamed(AppRoute.fileManager_explorer.name,
            pathParameters: {'path': folder.absolutPath}, extra: folder);
        ref.invalidateSelf();
      default:
        // Do Nothing!
        break;
    }
  }

  void _onOperationCanceled(bool isUpload) {
    final prefix = isUpload ? 'upload' : 'download';
    ref.read(snackBarServiceProvider).show(SnackBarConfig(
          type: SnackbarType.warning,
          title: tr('pages.files.file_operation.${prefix}_canceled.title'),
          message: tr('pages.files.file_operation.${prefix}_canceled.body'),
        ));
  }

  void _onOperationError(Object error, StackTrace stack, bool isUpload) {
    final prefix = isUpload ? 'upload' : 'download';
    ref.read(snackBarServiceProvider).show(SnackBarConfig.stacktraceDialog(
          dialogService: _dialogService,
          snackTitle: tr('pages.files.file_operation.${prefix}_failed.title'),
          snackMessage: tr('pages.files.file_operation.${prefix}_failed.body'),
          exception: error,
          stack: stack,
        ));
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
  }) = __Model;

  bool get selectionMode => selectedFiles.isNotEmpty;
}