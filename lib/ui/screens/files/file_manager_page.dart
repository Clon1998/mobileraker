/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/enums/file_action_sheet_action_enum.dart';
import 'package:common/data/enums/gcode_file_action_sheet_action_enum.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/data/model/sort_configuration.dart';
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
import 'package:common/ui/components/nav/nav_drawer_view.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/src/cache_manager.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg/svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker/ui/screens/files/components/remote_file_list_tile.dart';
import 'package:mobileraker_pro/service/moonraker/job_queue_service.dart';
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
  const FileManagerPage({super.key, required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _AppBar(filePath: filePath),
      drawer: const NavigationDrawerWidget().unless(filePath.split('/').length > 1),
      bottomNavigationBar: _BottomNav(filePath: filePath).unless(context.isLargerThanCompact),
      // floatingActionButton: fab.unless(context.isLargerThanCompact),
      body: MachineConnectionGuard(
        onConnected: (_, machineUUID) => _ManagerBody(machineUUID: machineUUID, filePath: filePath),
      ),
    );
  }
}

class _AppBar extends HookConsumerWidget implements PreferredSizeWidget {
  const _AppBar({super.key, required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final split = filePath.split('/');
    final isRoot = split.length == 1;
    final title = split.last;
    final selMachine = ref.watch(selectedMachineProvider).valueOrNull;
    final themeData = Theme.of(context);

    final actions = [
      if (selMachine != null)
        Consumer(builder: (context, ref, _) {
          final controller = ref.watch(_modernFileManagerControllerProvider(selMachine.uuid, filePath).notifier);
          final enabled = ref.watch(_modernFileManagerControllerProvider(selMachine.uuid, filePath)
              .select((data) => data.folderContent.valueOrNull?.isNotEmpty == true));

          return IconButton(
            tooltip: tr('pages.files.search_files'),
            icon: const Icon(Icons.search),
            onPressed: controller.onSearch.only(enabled),
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

    return BottomNavigationBar(
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
        padding: const EdgeInsets.only(right: 12),
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

class _FileList extends ConsumerStatefulWidget {
  const _FileList({super.key, required this.machineUUID, required this.filePath});

  final String machineUUID;

  final String filePath;

  @override
  ConsumerState createState() => _FileListState();
}

class _FileListState extends ConsumerState<_FileList> {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);

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
      loading: () => const _FileListLoading(),
      data: (data) {
        final content = data.unwrapped;

        if (content.isEmpty) {
          final themeData = Theme.of(context);

          return Center(
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
            controller.refreshApiResponse().then(
              (_) {
                _refreshController.refreshCompleted();
              },
              onError: (e, s) {
                logger.e(e, s);
                _refreshController.refreshFailed();
              },
            );
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
                child: _LoadingIndicator(machineUUID: widget.machineUUID, filePath: widget.filePath),
              ),
              SliverList.separated(
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
                    enabled: !folderContent.isLoading,
                    machineUUID: widget.machineUUID,
                    file: file,
                    dateFormat: dateFormat,
                    sortMode: sortConfiguration.mode,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}

class _LoadingIndicator extends ConsumerWidget {
  const _LoadingIndicator({super.key, required this.machineUUID, required this.filePath});

  final String machineUUID;

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_modernFileManagerControllerProvider(machineUUID, filePath));

    double? value = switch (model) {
      _Model(folderContent: AsyncValue(isReloading: true)) || _Model(download: FileDownloadKeepAlive()) => null,
      _Model(download: FileDownloadProgress(:final progress)) => progress,
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
    this.enabled = true,
  });

  final String machineUUID;
  final RemoteFile file;
  final DateFormat dateFormat;
  final SortMode sortMode;

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_modernFileManagerControllerProvider(machineUUID, file.parentPath).notifier);
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
      subtitle: subtitle,
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz, size: 22),
        onPressed: () {
          final box = context.findRenderObject() as RenderBox?;
          final pos = box!.localToGlobal(Offset.zero) & box.size;

          controller.onClickFileAction(file, pos);
        }.only(enabled),
      ),
      onTap: () {
        controller.onClickFile(file);
      }.only(enabled),
    );
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

  List<SortMode> get _availableSortModes => switch (_root) {
        'gcodes' => [SortMode.name, SortMode.lastModified, SortMode.lastPrinted, SortMode.size],
        _ => [SortMode.name, SortMode.lastModified, SortMode.size],
      };

  CompositeKey get _sortModeKey => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, 'mode:$_root');

  CompositeKey get _sortKindKey => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, 'kind:$_root');

  bool _disposed = false;

  CancelToken? _downloadToken;

  @override
  _Model build(String machineUUID, [String filePath = 'gcodes']) {
    ref.keepAliveFor();
    ref.onDispose(dispose);

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
        _goRouter.pushNamed(AppRoute.fileManager_explorer.name, pathParameters: {'path': file.absolutPath});
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
              '^[\\w.\\-]+\$',
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

  Future<void> refreshApiResponse() {
    logger.i('[ModernFileManagerController($machineUUID, $filePath)] refreshing api response');
    // ref.invalidate(fileApiResponseProvider(machineUUID, filePath));
    ref.invalidate(moonrakerFolderContentProvider);
    return ref.refresh(fileApiResponseProvider(machineUUID, filePath).future);
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
          suffixText: file.fileExtension,
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.match(
              '^[\\w.-]+\$',
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
      queryParameters: {'machineUUID': machineUUID},
    );

    if (res case String()) {
      if (file.parentPath == res) return;
      logger.i('[ModernFileManagerController($machineUUID, $filePath)] moving file ${file.name} to $res');
      state = state.copyWith(folderContent: state.folderContent.toLoading(true));
      _fileService.moveFile(file.absolutPath, res).ignore();
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
        if (a is FileDownloadProgress && b is FileDownloadProgress) {
          return (b.progress - a.progress) < epsilon;
        }

        return a == b;
      });

      await for (var download in downloadStream) {
        if (_disposed) break;
        if (!setToken) _downloadToken = download.token;
        state = state.copyWith(download: download);
      }

      if (_disposed) return;
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
    } catch (e) {
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.error,
            title: 'Error while downloading file for sharing.',
            message: e.toString(),
          ));
    } finally {
      state = state.copyWith(download: null);
    }
  }

  void dispose() {
    _disposed = true;
    _downloadToken?.cancel();
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required AsyncValue<FolderContentWrapper> folderContent,
    required SortConfiguration sortConfiguration,
    FileDownload? download,
  }) = __Model;
}
