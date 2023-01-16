import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/files/folder.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/files/remote_file.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/ease_in.dart';
import 'package:mobileraker/ui/components/selected_printer_app_bar.dart';
import 'package:mobileraker/ui/screens/files/components/file_sort_mode_selector.dart';
import 'package:mobileraker/ui/screens/files/files_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:shimmer/shimmer.dart';

class FilesPage extends ConsumerWidget {
  const FilesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      appBar: _AppBar(),
      drawer: NavigationDrawerWidget(),
      bottomNavigationBar: _BottomNav(),
      body: ConnectionStateView(
        onConnected: _FilesBody(),
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(selectedMachineProvider).valueOrFullNull == null) {
      return const SizedBox.shrink();
    }

    return BottomNavigationBar(
      showSelectedLabels: true,
      currentIndex: ref.watch(filePageProvider),
      onTap: (i) => ref.read(filePageProvider.notifier).state = i,
      // onTap: model.onBottomItemTapped,
      items: const [
        BottomNavigationBarItem(
            label: 'GCodes',
            icon: Icon(FlutterIcons.printer_3d_nozzle_outline_mco)),
        BottomNavigationBarItem(
            label: 'Configs', icon: Icon(FlutterIcons.file_code_faw5)),
      ],
    );
  }
}

class _AppBar extends HookConsumerWidget implements PreferredSizeWidget {
  const _AppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    var onBackground = themeData.appBarTheme.foregroundColor ??
        (themeData.colorScheme.brightness == Brightness.dark
            ? themeData.colorScheme.onSurface
            : themeData.colorScheme.onPrimary);

    TextEditingController textCtler =
        ref.watch(searchTextEditingControllerProvider);

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
            style: themeData.textTheme.headline6?.copyWith(color: onBackground),
            decoration: InputDecoration(
              hintText: '${tr('pages.files.search_files')}...',
              hintStyle: themeData.textTheme.headline6
                  ?.copyWith(color: onBackground.withOpacity(0.4)),
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
    } else {
      return SwitchPrinterAppBar(
          title: tr('pages.files.title'),
          actions: <Widget>[
            const FileSortModeSelector(),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () =>
                  ref.read(isSearchingProvider.notifier).state = true,
            ),
          ]);
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _FilesBody extends ConsumerWidget {
  const _FilesBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var theme = Theme.of(context);

    return WillPopScope(
      onWillPop: ref.watch(filesListControllerProvider.notifier).onWillPop,
      child: Container(
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(10)),
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
            const _BreadCrumb(),
            ref
                .watch(filesListControllerProvider.select((value) => value))
                .filteredAndSorted
                .when(
                    data: (folderContent) {
                      int lenFolders = folderContent.folders.length;
                      int lenGcodes = folderContent.files.length;
                      int lenTotal = lenFolders + lenGcodes;
                      var isSubFolder =
                          folderContent.folderPath.split('/').length > 1;

                      // Add one of the .. folder to back
                      if (isSubFolder) lenTotal++;

                      return Expanded(
                        child: EaseIn(
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOutCubic,
                          child: SmartRefresher(
                            header: const WaterDropMaterialHeader(),
                            controller: RefreshController(),
                            onRefresh: () =>
                                ref.invalidate(filesListControllerProvider),
                            child: (lenTotal == 0)
                                ? ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: Icon(Icons.search_off)),
                                    title:
                                        const Text('pages.files.no_files_found')
                                            .tr(),
                                  )
                                : ListView.builder(
                                    itemCount: lenTotal,
                                    itemBuilder: (context, index) {
                                      if (isSubFolder) {
                                        if (index == 0) {
                                          return ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 5, vertical: 3),
                                            leading: const SizedBox(
                                                width: 64,
                                                height: 64,
                                                child: Icon(Icons.folder)),
                                            title: const Text('...'),
                                            onTap: ref
                                                .watch(
                                                    filesListControllerProvider
                                                        .notifier)
                                                .popFolder,
                                          );
                                        } else {
                                          index--;
                                        }
                                      }

                                      if (index < lenFolders) {
                                        Folder folder =
                                            folderContent.folders[index];
                                        return FolderItem(
                                          folder: folder,
                                          key: ValueKey(folder),
                                        );
                                      } else {
                                        RemoteFile file = folderContent
                                            .files[index - lenFolders];
                                        if (file is GCodeFile) {
                                          return GCodeFileItem(
                                            gCode: file,
                                            key: ValueKey(file),
                                          );
                                        } else {
                                          return FileItem(
                                              file: file, key: ValueKey(file));
                                        }
                                      }
                                    }),
                          ),
                        ),
                      );
                    },
                    error: (e, s) => const Text('Could not fetch files!'),
                    loading: () => Expanded(
                          child: Shimmer.fromColors(
                            baseColor: Colors.grey,
                            highlightColor: theme.colorScheme.background,
                            child: ListView.builder(
                                itemCount: 15,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    leading: Container(
                                      width: 64,
                                      height: 64,
                                      color: Colors.white,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 2, horizontal: 2),
                                    ),
                                    title: Container(
                                      width: double.infinity,
                                      height: 16.0,
                                      margin: const EdgeInsets.only(right: 5),
                                      color: Colors.white,
                                    ),
                                  );
                                }),
                          ),
                        )),
          ],
        ),
      ),
    );
  }
}

class _BreadCrumb extends ConsumerWidget {
  const _BreadCrumb({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ThemeData theme = Theme.of(context);
    var curPath =
        ref.watch(filesListControllerProvider.select((value) => value.path));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: BreadCrumb.builder(
                itemCount: curPath.length,
                builder: (index) {
                  String p = curPath[index];
                  List<String> target = curPath.sublist(0, index + 1);
                  return BreadCrumbItem(
                      content: Text(
                        p.toUpperCase(),
                        style: theme.textTheme.subtitle1
                            ?.copyWith(color: theme.colorScheme.onPrimary),
                      ),
                      onTap: () => ref
                          .read(filesListControllerProvider.notifier)
                          .fetchDirectoryData(target));
                },
                divider: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    '/',
                    style: theme.textTheme.subtitle1
                        ?.copyWith(color: theme.colorScheme.onPrimary),
                  ),
                ),
              ),
            ),
            IconButton(
              padding: const EdgeInsets.only(left: 4),
              constraints: const BoxConstraints(),
              iconSize: 20,
              color: theme.colorScheme.onPrimary,
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: ref
                  .watch(filesListControllerProvider.notifier)
                  .onCreateDirTapped,
            )
          ],
        ),
      ),
    );
  }
}

class FolderItem extends ConsumerWidget {
  final Folder folder;

  const FolderItem({Key? key, required this.folder}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Slideable(
      fileName: folder.name,
      isFolder: true,
      child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          leading:
              const SizedBox(width: 64, height: 64, child: Icon(Icons.folder)),
          title: Text(folder.name),
          onTap: () => ref
              .read(filesListControllerProvider.notifier)
              .enterFolder(folder)),
    );
  }
}

class FileItem extends ConsumerWidget {
  final RemoteFile file;

  const FileItem({Key? key, required this.file}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Slideable(
      fileName: file.name,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: const SizedBox(
            width: 64, height: 64, child: Icon(Icons.insert_drive_file)),
        title: Text(file.name),
        onTap: () =>
            ref.read(filesListControllerProvider.notifier).onFileTapped(file),
      ),
    );
  }
}

class GCodeFileItem extends ConsumerWidget {
  final GCodeFile gCode;

  const GCodeFileItem({Key? key, required this.gCode}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? lastPrinted = gCode.lastPrintDate != null
        ? DateFormat.yMd(context.deviceLocale.languageCode).add_jm().format(gCode.lastPrintDate!)
        : null;

    return _Slideable(
      fileName: gCode.name,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: SizedBox(
            width: 64,
            height: 64,
            child: Hero(
              tag: 'gCodeImage-${gCode.hashCode}',
              child: buildLeading(
                  gCode, ref.watch(selectedMachineProvider).valueOrFullNull),
            )),
        title: Text(gCode.name),
        subtitle:  Text((lastPrinted != null)?'${tr('pages.files.last_printed')}: $lastPrinted':tr('pages.files.not_printed')),
        onTap: () =>
            ref.read(filesListControllerProvider.notifier).onFileTapped(gCode),
      ),
    );
  }

  Widget buildLeading(GCodeFile gCodeFile, Machine? machine) {
    String? printerUrl = machine?.httpUrl;
    if (printerUrl != null && gCodeFile.bigImagePath != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: CachedNetworkImage(
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15.0), right: Radius.circular(15.0)),
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(-1, 1), // changes position of shadow
                ),
              ],
            ),
          ),
          imageUrl:
              '$printerUrl/server/files/${gCode.parentPath}/${gCode.bigImagePath}',
          placeholder: (context, url) => const Icon(Icons.insert_drive_file),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      );
    } else {
      return const Icon(Icons.insert_drive_file);
    }
  }
}

class _Slideable extends ConsumerWidget {
  const _Slideable(
      {required this.child, required this.fileName, this.isFolder = false});

  final Widget child;
  final String fileName;
  final bool isFolder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            // An action can be bigger than the others.
            onPressed: (c) => (isFolder)
                ? ref
                    .watch(filesListControllerProvider.notifier)
                    .onRenameDirTapped(fileName)
                : ref
                    .watch(filesListControllerProvider.notifier)
                    .onRenameFileTapped(fileName),
            backgroundColor: themeData.colorScheme.secondaryContainer,
            foregroundColor: themeData.colorScheme.onSecondaryContainer,
            icon: Icons.drive_file_rename_outline,
            label: 'Rename',
          ),
          SlidableAction(
            onPressed: (c) => (isFolder)
                ? ref
                    .read(filesListControllerProvider.notifier)
                    .onDeleteDirTapped(MaterialLocalizations.of(c), fileName)
                : ref
                    .read(filesListControllerProvider.notifier)
                    .onDeleteFileTapped(MaterialLocalizations.of(c), fileName),
            backgroundColor: themeData.colorScheme.secondaryContainer.darken(5),
            foregroundColor: themeData.colorScheme.onSecondaryContainer,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: child,
    );
  }
}
