/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:badges/badges.dart' as badges;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/exceptions/file_fetch_exception.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/mobileraker_icon_button.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/gcode_file_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/remote_file_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:flutter_cache_manager/src/cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/ease_in.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/screens/files/components/file_sort_mode_selector.dart';
import 'package:mobileraker/ui/screens/files/files_controller.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:shimmer/shimmer.dart';

import '../../components/connection/machine_connection_guard.dart';

class FilesPage extends ConsumerWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = MachineConnectionGuard(
      onConnected: (_, machineUUID) => _FilesBody(machineUUID: machineUUID),
      skipKlipperReady: true,
    );

    if (context.isLargerThanCompact) {
      body = Row(
        children: [const NavigationRailView(), Expanded(child: body)],
      );
    }
    return Scaffold(
      appBar: const _AppBar(),
      drawer: const NavigationDrawerWidget(),
      bottomNavigationBar: const _BottomNav().unless(context.isLargerThanCompact),
      floatingActionButton: const _Fab(),
      body: body,
    );
  }
}

class _Fab extends ConsumerWidget {
  const _Fab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var jobQueueStatusAsync = ref.watch(
      filesPageControllerProvider.select((value) => value.jobQueueStatus),
    );
    if (jobQueueStatusAsync.isLoading || jobQueueStatusAsync.hasError) {
      return const SizedBox.shrink();
    }
    var jobQueueStatus = jobQueueStatusAsync.requireValue;

    if (jobQueueStatus.queuedJobs.isEmpty) {
      return const SizedBox.shrink();
    }
    var themeData = Theme.of(context);
    return FloatingActionButton(
      onPressed: ref.read(filesPageControllerProvider.notifier).jobQueueBottomSheet,
      child: badges.Badge(
        badgeStyle: badges.BadgeStyle(
          badgeColor: themeData.colorScheme.onSecondary,
        ),
        badgeAnimation: const badges.BadgeAnimation.rotation(),
        position: badges.BadgePosition.bottomEnd(end: -7, bottom: -11),
        badgeContent: Text(
          '${jobQueueStatus.queuedJobs.length}',
          style: TextStyle(color: themeData.colorScheme.secondary),
        ),
        child: const Icon(Icons.content_paste),
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(selectedMachineProvider).valueOrFullNull == null) {
      return const SizedBox.shrink();
    }

    // ref.watch(provider)

    return BottomNavigationBar(
      showSelectedLabels: true,
      currentIndex: ref.watch(filePageProvider),
      onTap: ref.read(filePageProvider.notifier).onPageTapped,
      // onTap: model.onBottomItemTapped,
      items: [
        BottomNavigationBarItem(
          label: tr('pages.files.gcode_tab'),
          icon: const Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
        ),
        BottomNavigationBarItem(
          label: tr('pages.files.config_tab'),
          icon: const Icon(FlutterIcons.file_code_faw5),
        ),
        if (ref.watch(klipperSelectedProvider.selectAs((data) => data.hasTimelapseComponent)).valueOrNull == true)
          BottomNavigationBarItem(
            label: tr('pages.files.timelapse_tab'),
            icon: const Icon(Icons.subscriptions_outlined),
          ),
      ],
    );
  }
}

class _AppBar extends HookConsumerWidget implements PreferredSizeWidget {
  const _AppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);

    final onBackground = themeData.appBarTheme.foregroundColor ??
        (themeData.colorScheme.brightness == Brightness.dark
            ? themeData.colorScheme.onSurface
            : themeData.colorScheme.onPrimary);

    TextEditingController textCtler = ref.watch(searchTextEditingControllerProvider);

    final areFilesReady = ref.watch(filesPageControllerProvider.select((value) => value.areFilesReady));

    if (ref.watch(isSearchingProvider)) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(isSearchingProvider.notifier).state = false,
        ),
        title: EaseIn(
          curve: Curves.easeOutCubic,
          child: TextField(
            controller: textCtler,
            autofocus: true,
            cursorColor: onBackground,
            style: themeData.textTheme.titleLarge?.copyWith(color: onBackground),
            decoration: InputDecoration(
              hintText: '${tr('pages.files.search_files')}...',
              hintStyle: themeData.textTheme.titleLarge?.copyWith(color: onBackground.withOpacity(0.4)),
              border: InputBorder.none,
              suffixIcon: textCtler.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'pages.files.clear_search'.tr(),
                      icon: const Icon(Icons.close),
                      color: onBackground,
                      onPressed: textCtler.clear,
                    ),
            ),
          ),
        ),
      );
    }
    return SwitchPrinterAppBar(
      title: tr('pages.files.title'),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: MachineStateIndicator(
            ref.watch(selectedMachineProvider).valueOrFullNull,
          ),
        ),
        const FileSortModeSelector(),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: areFilesReady ? () => ref.read(isSearchingProvider.notifier).state = true : null,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _FilesBody extends ConsumerWidget {
  const _FilesBody({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var theme = Theme.of(context);

    var controller = ref.watch(filesPageControllerProvider.notifier);
    var borderSize = BorderSide(width: 0.5, color: theme.colorScheme.primary);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        var pop = await controller.onWillPop();
        var naviator = Navigator.of(context);
        if (pop && naviator.canPop()) {
          naviator.pop();
        }
      },
      child: Container(
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(bottom: borderSize, left: borderSize, right: borderSize),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
          boxShadow: [
            if (theme.brightness == Brightness.light)
              const BoxShadow(
                color: Colors.grey,
                offset: Offset(0.0, 4.0), //(x,y)
                blurRadius: 1.0,
              ),
          ],
        ),
        child: Column(
          children: [
            _Header(machineUUID: machineUUID),
            Expanded(
              child: ref
                  .watch(
                    filesPageControllerProvider.select((value) => value.files),
                  )
                  .when(
                    skipLoadingOnReload: true,
                    skipLoadingOnRefresh: false,
                    data: (files) => _FilesData(files: files),
                    error: (e, s) => _FilesError(error: e, stack: s),
                    loading: () => _FilesLoading(theme: theme),
                  ),
            ),
            // _BottomNav(),
          ],
        ),
      ),
    );
  }
}

class _FilesLoading extends StatelessWidget {
  const _FilesLoading({
    super.key,
    required this.theme,
  });

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey,
      highlightColor: theme.colorScheme.background,
      child: ListView.builder(
        itemBuilder: (context, index) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 2,
            ),
            leading: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(15.0),
                  right: Radius.circular(15.0),
                ),
                color: Colors.white,
              ),
              width: 64,
              height: 64,
              margin: const EdgeInsets.symmetric(
                vertical: 2,
                horizontal: 2,
              ),
            ),
            title: Container(
              width: double.infinity,
              height: 16.0,
              margin: const EdgeInsets.only(right: 5),
              color: Colors.white,
            ),
            subtitle: Row(
              children: [
                Flexible(
                  child: Container(
                    width: double.infinity,
                    height: 10.0,
                    color: Colors.white,
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilesError extends ConsumerWidget {
  const _FilesError({
    super.key,
    required this.error,
    required this.stack,
  });

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
              onPressed: ref.read(filesPageControllerProvider.notifier).refreshFiles,
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

class _FilesData extends ConsumerStatefulWidget {
  const _FilesData({super.key, required this.files});

  final FolderContentWrapper files;

  @override
  ConsumerState createState() => _FilesDataState();
}

class _FilesDataState extends ConsumerState<_FilesData> {
  RefreshController _refreshController = RefreshController(initialRefresh: false);

  @override
  Widget build(BuildContext context) {
    var model = ref.watch(filesPageControllerProvider);
    var controller = ref.watch(filesPageControllerProvider.notifier);

    int lenFolders = widget.files.folders.length;
    int lenGcodes = widget.files.files.length;
    int lenTotal = lenFolders + lenGcodes;

    // Add one of the .. folder to back
    if (model.isInSubFolder) lenTotal++;

    return EaseIn(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: SmartRefresher(
        header: const WaterDropMaterialHeader(),
        controller: _refreshController,
        onRefresh: controller.refreshFiles,
        child: (lenTotal == 0)
            ? ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(Icons.search_off),
                ),
                title: const Text('pages.files.no_files_found').tr(),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: lenTotal,
                itemBuilder: (context, index) {
                  if (model.isInSubFolder) {
                    if (index == 0) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 3,
                        ),
                        leading: const SizedBox(
                          width: 64,
                          height: 64,
                          child: Icon(Icons.folder),
                        ),
                        title: const Text('...'),
                        onTap: controller.popFolder,
                      );
                    }
                    index--;
                  }

                  if (index < lenFolders) {
                    Folder folder = widget.files.folders[index];
                    return _FolderItem(folder: folder, key: ValueKey(folder));
                  }
                  RemoteFile file = widget.files.files[index - lenFolders];
                  if (file is GCodeFile) {
                    return _GCodeFileItem(key: ValueKey(file), gCode: file);
                  }
                  if (file.isImage) {
                    return _ImageFileItem(key: ValueKey(file), file: file);
                  }

                  return _FileItem(file: file, key: ValueKey(file));
                },
              ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}

class _Header extends HookConsumerWidget {
  const _Header({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTimelapse =
        ref.watch(klipperProvider(machineUUID).selectAs((data) => data.hasTimelapseComponent)).requireValue == true;

    final tabController = useTabController(initialLength: hasTimelapse ? 3 : 2, keys: [machineUUID, hasTimelapse]);

    // That is used to sync Riverpod and tab controller (Also it would be better to refactor that...)
    final filePageIdx = ref.read(filePageProvider);
    if (tabController.index != filePageIdx && !tabController.indexIsChanging) {
      tabController.index = filePageIdx;
    }

    final themeData = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: themeData.colorScheme.primary),
      child: Column(
        children: [
          if (context.isLargerThanCompact)
            TabBar(
              onTap: ref.read(filePageProvider.notifier).onPageTapped,
              controller: tabController,
              labelStyle: themeData.textTheme.labelLarge,
              labelColor: themeData.colorScheme.onPrimary,
              dividerHeight: 0.5,
              indicatorColor: themeData.colorScheme.onPrimary,
              enableFeedback: true,
              tabs: [
                Tab(
                  icon: const Icon(FlutterIcons.printer_3d_nozzle_outline_mco),
                  text: tr('pages.files.gcode_tab'),
                ),
                Tab(
                  icon: const Icon(FlutterIcons.file_code_faw5),
                  text: tr('pages.files.config_tab'),
                ),
                if (hasTimelapse)
                  Tab(
                    icon: const Icon(Icons.subscriptions_outlined),
                    text: tr('pages.files.timelapse_tab'),
                  ),
              ],
            ),
          const _BreadCrumb(),
        ],
      ),
    );
  }
}

class _BreadCrumb extends ConsumerWidget {
  const _BreadCrumb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeData theme = Theme.of(context);
    final model = ref.watch(filesPageControllerProvider.select((value) => value.path));
    final enableButton = ref.watch(filesPageControllerProvider.select((value) => value.areFilesReady));
    final controller = ref.watch(filesPageControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: BreadCrumb.builder(
              itemCount: model.length,
              builder: (index) {
                String p = model[index];
                List<String> target = model.sublist(0, index + 1);
                return BreadCrumbItem(
                  content: Text(
                    p.toUpperCase(),
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimary),
                  ),
                  onTap: () => controller.goToPath(target),
                );
              },
              divider: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  '/',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimary),
                ),
              ),
            ),
          ),
          MobilerakerIconButton(
            padding: const EdgeInsets.only(left: 4),
            onPressed: ref.watch(filesPageControllerProvider.notifier).onCreateDirTapped.only(enableButton),
            color: theme.colorScheme.onPrimary,
            // disabledColor: Colors.redAccent,
            icon: const Icon(
              Icons.create_new_folder_outlined,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderItem extends ConsumerWidget {
  final Folder folder;

  const _FolderItem({super.key, required this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(filesPageControllerProvider.notifier);

    return _Slideable(
      file: folder,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: const SizedBox(width: 64, height: 64, child: Icon(Icons.folder)),
        title: Text(folder.name),
        onTap: () => controller.enterFolder(folder),
      ),
    );
  }
}

class _FileItem extends ConsumerWidget {
  final RemoteFile file;

  const _FileItem({super.key, required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(filesPageControllerProvider.notifier);
    var modified = ref
        .read(dateFormatServiceProvider)
        .add_Hm(DateFormat.yMd(context.deviceLocale.languageCode))
        .format(file.modifiedDate);

    return _Slideable(
      file: file,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: const SizedBox(
          width: 64,
          height: 64,
          child: Icon(Icons.insert_drive_file),
        ),
        title: Text(file.name),
        subtitle: Text('${tr('pages.files.last_mod')}: $modified'),
        onTap: () => controller.onFileTapped(file),
      ),
    );
  }
}

class _ImageFileItem extends ConsumerWidget {
  final RemoteFile file;

  const _ImageFileItem({super.key, required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var modified = ref
        .read(dateFormatServiceProvider)
        .add_Hm(DateFormat.yMd(context.deviceLocale.languageCode))
        .format(file.modifiedDate);

    var controller = ref.watch(filesPageControllerProvider.notifier);
    var imageBaseUri = ref.watch(previewImageUriProvider);
    var imageHeaders = ref.watch(previewImageHttpHeaderProvider);
    var imageUri = file.downloadUri(imageBaseUri);
    var machineUUID = ref.watch(selectedMachineProvider.select((value) => value.requireValue!.uuid));
    var cacheManager = ref.watch(httpCacheManagerProvider(machineUUID));

    return _Slideable(
      file: file,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: SizedBox(
          width: 64,
          height: 64,
          child: Hero(
            transitionOnUserGestures: true,
            tag: 'img-${file.hashCode}',
            child: CachedNetworkImage(
              cacheManager: cacheManager,
              cacheKey: '${imageUri.hashCode}-${file.hashCode}',
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(15.0),
                    right: Radius.circular(15.0),
                  ),
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(-1, 1), // changes position of shadow
                    ),
                  ],
                ),
              ),
              imageUrl: imageUri.toString(),
              httpHeaders: imageHeaders,
              placeholder: (context, url) => const Icon(Icons.image),
              errorWidget: (context, url, error) {
                logger.w(url);
                logger.e(error);
                return const Icon(Icons.error);
              },
            ),
          ),
        ),
        title: Text(file.name),
        subtitle: Text('${tr('pages.files.last_mod')}: $modified'),
        onTap: () => controller.onFileTapped(file),
      ),
    );
  }
}

class _GCodeFileItem extends ConsumerWidget {
  final GCodeFile gCode;

  const _GCodeFileItem({super.key, required this.gCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? lastPrinted = gCode.lastPrintDate != null
        ? ref
            .read(dateFormatServiceProvider)
            .add_Hm(DateFormat.yMd(context.deviceLocale.languageCode))
            .format(gCode.lastPrintDate!)
        : null;
    var themeData = Theme.of(context);
    var machineUUID = ref.watch(selectedMachineProvider.select((value) => value.requireValue!.uuid));
    var cacheManager = ref.watch(httpCacheManagerProvider(machineUUID));

    return _Slideable(
      file: gCode,
      startActionPane: ActionPane(motion: const StretchMotion(), children: [
        SlidableAction(
          // An action can be bigger than the others.
          onPressed: (_) => ref.read(filesPageControllerProvider.notifier).onAddToQueueTapped(gCode),
          backgroundColor: themeData.colorScheme.primaryContainer,
          foregroundColor: themeData.colorScheme.onPrimaryContainer,
          icon: Icons.queue_outlined,
          label: 'Queue',
        ),
      ]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: SizedBox(
          width: 64,
          height: 64,
          child: Hero(
            transitionOnUserGestures: true,
            tag: 'gCodeImage-${gCode.hashCode}',
            child: buildLeading(
              gCode,
              ref.watch(previewImageUriProvider),
              ref.watch(previewImageHttpHeaderProvider),
              cacheManager,
            ),
          ),
        ),
        title: Text(gCode.name),
        subtitle: Text(
          (lastPrinted != null) ? '${tr('pages.files.last_printed')}: $lastPrinted' : tr('pages.files.not_printed'),
        ),
        onTap: () => ref.read(filesPageControllerProvider.notifier).onFileTapped(gCode),
      ),
    );
  }

  Widget buildLeading(
    GCodeFile gCodeFile,
    Uri? machineUri,
    Map<String, String> headers,
    CacheManager cacheManager,
  ) {
    var bigImageUri = gCodeFile.constructBigImageUri(machineUri);
    if (bigImageUri != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: CachedNetworkImage(
          cacheManager: cacheManager,
          cacheKey: '${bigImageUri.hashCode}-${gCodeFile.hashCode}',
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(15.0),
                right: Radius.circular(15.0),
              ),
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(-1, 1), // changes position of shadow
                ),
              ],
            ),
          ),
          imageUrl: bigImageUri.toString(),
          httpHeaders: headers,
          placeholder: (context, url) => const Icon(Icons.insert_drive_file),
          errorWidget: (context, url, error) {
            logger.w(url);
            logger.e(error);
            return const Icon(Icons.error);
          },
        ),
      );
    }
    return const Icon(Icons.insert_drive_file);
  }
}

class _Slideable extends ConsumerWidget {
  const _Slideable({
    required this.file,
    required this.child,
    this.startActionPane,
  });

  final Widget child;
  final RemoteFile file;
  final ActionPane? startActionPane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var controller = ref.watch(filesPageControllerProvider.notifier);

    return Slidable(
      startActionPane: startActionPane,
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            // An action can be bigger than the others.
            onPressed: (_) => controller.onRenameTapped(file),
            backgroundColor: themeData.colorScheme.secondaryContainer,
            foregroundColor: themeData.colorScheme.onSecondaryContainer,
            icon: Icons.drive_file_rename_outline,
            label: tr('general.rename'),
          ),
          SlidableAction(
            onPressed: (_) => controller.onDeleteTapped(file),
            backgroundColor: themeData.colorScheme.secondaryContainer.darken(5),
            foregroundColor: themeData.colorScheme.onSecondaryContainer,
            icon: Icons.delete_outline,
            label: tr('general.delete'),
          ),
        ],
      ),
      child: child,
    );
  }
}
