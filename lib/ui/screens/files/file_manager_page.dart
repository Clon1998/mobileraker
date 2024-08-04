/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
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
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';
import 'package:stringr/stringr.dart';

import '../../../routing/app_router.dart';
import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../../service/ui/dialog_service_impl.dart';
import '../../components/connection/machine_connection_guard.dart';
import '../../components/dialog/text_input/text_input_dialog.dart';

part 'file_manager_page.freezed.dart';

part 'file_manager_page.g.dart';

class FileManagerPage extends ConsumerWidget {
  const FileManagerPage({super.key, required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _AppBar(filePath: filePath),
      drawer: const NavigationDrawerWidget().unless(filePath!.split('/').length > 1),
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
    final title = filePath.split('/').last;
    final selMachine = ref.watch(selectedMachineProvider).valueOrNull;

    return AppBar(
      title: Text(title.capitalize()),
      actions: [
        if (selMachine != null)
          Consumer(builder: (context, ref, _) {
            final controller = ref.watch(_modernFileManagerControllerProvider(selMachine.uuid, filePath).notifier);
            final enabled = ref
                    .watch(_modernFileManagerControllerProvider(selMachine.uuid, filePath)
                        .selectAs((data) => data.folderContent.isNotEmpty))
                    .whenOrNull(
                      skipLoadingOnRefresh: true,
                      skipLoadingOnReload: true,
                      data: (d) => d,
                    ) ??
                false;

            return IconButton(
              icon: const Icon(Icons.search),
              onPressed: controller.onSearch.only(enabled),
            );
          }),
      ],
    );
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
        _Header(machineUUID: machineUUID, filePath: filePath),
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
    final sortCfg = ref
        .watch(_modernFileManagerControllerProvider(machineUUID, filePath).selectAs((data) => data.sortConfiguration))
        .valueOrNull;

    final labelText = sortCfg != null ? tr(sortCfg.mode.translation) : tr('pages.files.sort_by');

    final themeData = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: controller.onSortMode.only(sortCfg != null),
            label: Text(labelText, style: themeData.textTheme.bodySmall?.copyWith(fontSize: 13)),
            icon: AnimatedRotation(
              duration: kThemeAnimationDuration,
              curve: Curves.easeInOutCubicEmphasized,
              turns: sortCfg?.kind == SortKind.ascending ? 0 : 0.5,
              child: Icon(Icons.arrow_upward, size: 16, color: themeData.textTheme.bodySmall?.color),
            ),
            iconAlignment: IconAlignment.end,
          ),
          // Icon(Icons.arrow_upward, size: 17, color: themeData.textTheme.bodySmall?.color),
          // const _Search(),
          const Spacer(),

          IconButton(
            padding: const EdgeInsets.only(right: 6),
            // 12 is basis vom icon button + 4 weil list tile hat 14 padding + 1 wegen size 22
            onPressed: controller.onCreateFolder.only(sortCfg != null),
            // icon: Icon(Icons.more_horiz,size: 22),
            icon: Icon(Icons.create_new_folder, size: 22, color: themeData.textTheme.bodySmall?.color),
          ),
        ],
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
      child: ListView.separated(
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

    final model = ref.watch(_modernFileManagerControllerProvider(widget.machineUUID, widget.filePath));

    final themeData = Theme.of(context);

    return AsyncValueWidget(
      debugLabel: 'ModernFileManager._FileListState',
      value: model,
      skipLoadingOnReload: true,
      loading: () => const _FileListLoading(),
      data: (data) {
        final content = data.folderContent.unwrapped;

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
                Text('This folder is empty', style: themeData.textTheme.titleMedium),
                Text('No files found', style: themeData.textTheme.bodySmall),
              ],
            ),
          );
        }
        // Note Wrapping the listview in the SmartRefresher causes the UI to "Lag" because it renders the entire listview at once rather than making use of the builder???
        return SmartRefresher(
          // header: const WaterDropMaterialHeader(),
          header: ClassicHeader(
            textStyle: TextStyle(color: themeData.colorScheme.onBackground),
            idleIcon: Icon(
              Icons.arrow_upward,
              color: themeData.colorScheme.onBackground,
            ),
            completeIcon: Icon(Icons.done, color: themeData.colorScheme.onBackground),
            releaseIcon: Icon(
              Icons.refresh,
              color: themeData.colorScheme.onBackground,
            ),
            idleText: tr('components.pull_to_refresh.pull_up_idle'),
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
          child: ListView.separated(
            key: PageStorageKey('${widget.filePath}:${data.sortConfiguration.mode}:${data.sortConfiguration.kind}'),
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
                sortMode: data.sortConfiguration.mode,
              );
            },
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

class _FileItem extends ConsumerWidget {
  const _FileItem(
      {super.key, required this.machineUUID, required this.file, required this.dateFormat, required this.sortMode});

  final String machineUUID;
  final RemoteFile file;
  final DateFormat dateFormat;
  final SortMode sortMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_modernFileManagerControllerProvider(machineUUID, 'gcodes').notifier);
    var numberFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);

    Widget subtitle = switch (sortMode) {
      SortMode.size => Text(numberFormat.formatFileSize(file.size)),
      SortMode.lastPrinted when file is GCodeFile =>
        Text((file as GCodeFile).lastPrintDate?.let(dateFormat.format) ?? '--'),
      SortMode.lastPrinted => const Text('--'),
      SortMode.lastModified => Text(file.modifiedDate?.let(dateFormat.format) ?? '--'),
      _ => Text('@:pages.files.last_mod: ${file.modifiedDate?.let(dateFormat.format) ?? '--'}').tr(),
    };

    return RemoteFileListTile(
        machineUUID: machineUUID,
        file: file,
        subtitle: subtitle,
        trailing: IconButton(
          icon: const Icon(Icons.more_horiz, size: 22),
          onPressed: () {
            //TODO
          },
        ),
        onTap: () => controller.onClickFile(file));
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

  SettingService get _settingService => ref.read(settingServiceProvider);

  FileService get _fileService => ref.read(fileServiceProvider(machineUUID));

  // ignore: avoid-unsafe-collection-methods
  String get _root => filePath.split('/').first;

  List<SortMode> get _availableSortModes => switch (_root) {
        'gcodes' => [SortMode.name, SortMode.lastModified, SortMode.lastPrinted, SortMode.size],
        _ => [SortMode.name, SortMode.lastModified, SortMode.size],
      };

  CompositeKey get _sortModeKey => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, 'mode:$_root');

  CompositeKey get _sortKindKey => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, 'kind:$_root');

  @override
  FutureOr<_Model> build(String machineUUID, [String filePath = 'gcodes']) async {
    ref.keepAliveFor();

    logger.i('[ModernFileManagerController] fetching directory info for $filePath');

    final supportedModes = _availableSortModes;
    final sortModeIdx = ref.watch(intSettingProvider(_sortModeKey)).clamp(0, supportedModes.length - 1);
    final sortKindIdx = ref.watch(intSettingProvider(_sortKindKey)).clamp(0, SortKind.values.length - 1);

    // ignore: avoid-unsafe-collection-methods
    final sortConfiguration = SortConfiguration(supportedModes[sortModeIdx], SortKind.values[sortKindIdx]);

    //TODO: Add search term!
    final apiResp = await ref.watch(moonrakerFolderContentProvider(machineUUID, filePath, sortConfiguration).future);

    return _Model(
      folderContent: apiResp,
      sortConfiguration: sortConfiguration,
    );
  }

  void onClickFile(RemoteFile file) {
    logger.i('[ModernFileManagerController] opening file ${file.name} (${file.runtimeType})');

    switch (file) {
      case GCodeFile():
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_gcodeDetail.name, params: {'path': filePath}, extra: file);
        break;
      case Folder():
        _goRouter.pushNamed(AppRoute.fileManager_explorer.name, params: {'path': file.absolutPath});
        break;
      case RemoteFile(isVideo: true):
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_videoPlayer.name, params: {'path': filePath}, extra: file);
        break;
      case RemoteFile(isImage: true):
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_imageViewer.name, params: {'path': filePath}, extra: file);
        break;
      default:
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_editor.name, params: {'path': filePath}, extra: file);
    }
  }

  void onBottomItemTapped(int index) {
    logger.i('[ModernFileManagerController] bottom nav item tapped: $index');

    switch (index) {
      case 1:
        _goRouter.replaceNamed(AppRoute.fileManager_explorer.name, params: {'path': 'config'});
        break;
      case 2:
        _goRouter.replaceNamed(AppRoute.fileManager_explorer.name, params: {'path': 'timelapse'});
        break;
      default:
        _goRouter.replaceNamed(AppRoute.fileManager_explorer.name, params: {'path': 'gcodes'});
    }
  }

  void onCreateFolder() async {
    logger.i('[ModernFileManagerController] creating folder');

    final usedNames = state.requireValue.folderContent.unwrapped.map((e) => e.name).toList();

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
              errorText: tr('pages.files.file_name_in_use'),
            ),
          ]),
        ),
      ),
    );

    if (dialogResponse?.confirmed == true) {
      String newName = dialogResponse!.data;

      try {
        final res = await _fileService.createDir('$filePath/$newName');
        final folder = Folder.fromFileItem(res.item);
        state = state.whenData((data) {
          final updatedFolders = [...data.folderContent.folders, folder].sorted(data.sortConfiguration.comparator);

          return data.copyWith(folderContent: data.folderContent.copyWith(folders: updatedFolders));
        });
      } on JRpcError {
        // _snackBarService.showCustomSnackBar(
        //     variant: SnackbarType.error,
        //     duration: const Duration(seconds: 5),
        //     title: 'Error',
        //     message: 'Could not create folder!\n${e.message}');
      }
    }
  }

  Future<void> onSortMode() async {
    logger.i('[ModernFileManagerController] sort mode');
    final model = state.requireValue;
    final args = SortModeSheetArgs(
      toShow: _availableSortModes,
      active: model.sortConfiguration,
    );

    final res = await _bottomSheetService.show(BottomSheetConfig(type: SheetType.sortMode, data: args));

    if (res.confirmed == true) {
      logger.i('SortModeSheet confirmed: ${res.data}');

      // This is required to already show the new sort mode before the data is updated
      state = state.whenData((data) => data.copyWith(sortConfiguration: res.data));
      // This will trigger a rebuild!
      _settingService.writeInt(_sortModeKey, res.data.mode.index);
      _settingService.writeInt(_sortKindKey, res.data.kind.index);
    }
  }

  Future<void> onSearch() async {
    logger.i('[ModernFileManagerController] search');

    _goRouter.pushNamed(AppRoute.fileManager_exlorer_search.name,
        params: {'path': filePath}, queryParams: {'machineUUID': machineUUID});
    // _dialogService.show(DialogRequest(type: DialogType.searchFullscreen));
  }

  Future<void> refreshApiResponse() async {
    logger.i('[ModernFileManagerController] refreshing api response');
    return ref.refresh(fileApiResponseProvider(machineUUID, filePath).future);
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required FolderContentWrapper folderContent,
    required SortConfiguration sortConfiguration,
  }) = __Model;
}
