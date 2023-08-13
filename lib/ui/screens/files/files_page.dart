/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

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
import 'package:mobileraker/data/dto/files/remote_file_mixin.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/date_format_service.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/components/ease_in.dart';
import 'package:mobileraker/ui/components/error_card.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/components/selected_printer_app_bar.dart';
import 'package:mobileraker/ui/screens/files/components/file_sort_mode_selector.dart';
import 'package:mobileraker/ui/screens/files/files_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/extensions/gcode_file_extension.dart';
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
        skipKlipperReady: true,
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
            label: 'GCodes', icon: Icon(FlutterIcons.printer_3d_nozzle_outline_mco)),
        BottomNavigationBarItem(label: 'Configs', icon: Icon(FlutterIcons.file_code_faw5)),
        // BottomNavigationBarItem(label: 'Logs', icon: Icon(FlutterIcons.file_eye_outline_mco)),
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

    TextEditingController textCtler = ref.watch(searchTextEditingControllerProvider);

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
              hintStyle:
                  themeData.textTheme.titleLarge?.copyWith(color: onBackground.withOpacity(0.4)),
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
      return SwitchPrinterAppBar(title: tr('pages.files.title'), actions: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: MachineStateIndicator(ref.watch(selectedMachineProvider).valueOrFullNull),
        ),
        const FileSortModeSelector(),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => ref.read(isSearchingProvider.notifier).state = true,
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

    var model = ref.watch(filesPageControllerProvider);
    var controller = ref.watch(filesPageControllerProvider.notifier);

    return WillPopScope(
      onWillPop: controller.onWillPop,
      child: Container(
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
            const _BreadCrumb(),
            ref.watch(filesPageControllerProvider.select((value) => value.files)).when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: false,
                data: (files) {
                  int lenFolders = files.folders.length;
                  int lenGcodes = files.files.length;
                  int lenTotal = lenFolders + lenGcodes;

                  // Add one of the .. folder to back
                  if (model.isInSubFolder) lenTotal++;

                  return Expanded(
                    child: EaseIn(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeOutCubic,
                      child: SmartRefresher(
                        header: const WaterDropMaterialHeader(),
                        controller: RefreshController(),
                        onRefresh: controller.refreshFiles,
                        child: (lenTotal == 0)
                            ? ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const SizedBox(
                                    width: 64, height: 64, child: Icon(Icons.search_off)),
                                title: const Text('pages.files.no_files_found').tr(),
                              )
                            : ListView.builder(
                                itemCount: lenTotal,
                                itemBuilder: (context, index) {
                                  if (model.isInSubFolder) {
                                    if (index == 0) {
                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                        leading: const SizedBox(
                                            width: 64, height: 64, child: Icon(Icons.folder)),
                                        title: const Text('...'),
                                        onTap: controller.popFolder,
                                      );
                                    } else {
                                      index--;
                                    }
                                  }

                                  if (index < lenFolders) {
                                    Folder folder = files.folders[index];
                                    return FolderItem(
                                      folder: folder,
                                      key: ValueKey(folder),
                                    );
                                  } else {
                                    RemoteFile file = files.files[index - lenFolders];
                                    if (file is GCodeFile) {
                                      return GCodeFileItem(
                                        key: ValueKey(file),
                                        gCode: file,
                                      );
                                    } else {
                                      return FileItem(
                                        file: file,
                                        key: ValueKey(file),
                                      );
                                    }
                                  }
                                }),
                      ),
                    ),
                  );
                },
                error: (e, s) => Expanded(
                      child: ErrorCard(
                        title: const Text('Unable to fetch files!'),
                        body: Column(
                          children: [
                            Text('The following error occued while trying to fetch files:n$e'),
                            TextButton(
                                // onPressed: model.showPrinterFetchingErrorDialog,
                                onPressed: () => ref.read(dialogServiceProvider).show(DialogRequest(
                                    type: DialogType.stacktrace,
                                    title: e.runtimeType.toString(),
                                    body: 'Exception:\n $e\n\n$s')),
                                child: const Text('Show Full Error'))
                          ],
                        ),
                      ),
                    ),
                loading: () => Expanded(
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey,
                        highlightColor: theme.colorScheme.background,
                        child: ListView.builder(
                            itemCount: 15,
                            itemBuilder: (context, index) {
                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                leading: Container(
                                  decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.horizontal(
                                        left: Radius.circular(15.0), right: Radius.circular(15.0)),
                                    color: Colors.white,
                                  ),
                                  width: 64,
                                  height: 64,
                                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
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
                                    const Spacer(
                                      flex: 2,
                                    )
                                  ],
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
    var model = ref.watch(filesPageControllerProvider.select((value) => value.path));
    var controller = ref.watch(filesPageControllerProvider.notifier);

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
                itemCount: model.length,
                builder: (index) {
                  String p = model[index];
                  List<String> target = model.sublist(0, index + 1);
                  return BreadCrumbItem(
                      content: Text(
                        p.toUpperCase(),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: theme.colorScheme.onPrimary),
                      ),
                      onTap: () => controller.goToPath(target));
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
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: InkWell(
                onTap: ref.watch(filesPageControllerProvider.notifier).onCreateDirTapped,
                child: Icon(
                  Icons.create_new_folder_outlined,
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                ),
              ),
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
    var controller = ref.watch(filesPageControllerProvider.notifier);

    return _Slideable(
      file: folder,
      child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          leading: const SizedBox(width: 64, height: 64, child: Icon(Icons.folder)),
          title: Text(folder.name),
          onTap: () => controller.enterFolder(folder)),
    );
  }
}

class FileItem extends ConsumerWidget {
  final RemoteFile file;

  const FileItem({Key? key, required this.file}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(filesPageControllerProvider.notifier);

    return _Slideable(
      file: file,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: const SizedBox(width: 64, height: 64, child: Icon(Icons.insert_drive_file)),
        title: Text(file.name),
        onTap: () => controller.onFileTapped(file),
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
        ? ref
            .read(dateFormatServiceProvider)
            .add_Hm(DateFormat.yMd(context.deviceLocale.languageCode))
            .format(gCode.lastPrintDate!)
        : null;

    return _Slideable(
      file: gCode,
      // startActionPane: ActionPane(motion: const StretchMotion(), children: [
      //   SlidableAction(
      //     // An action can be bigger than the others.
      //     onPressed: (_) => controller.onRenameTapped(file),
      //     backgroundColor: themeData.colorScheme.secondaryContainer,
      //     foregroundColor: themeData.colorScheme.onSecondaryContainer,
      //     icon: Icons.drive_file_rename_outline,
      //     label: tr('general.rename'),
      //   ),
      // ]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: SizedBox(
            width: 64,
            height: 64,
            child: Hero(
              tag: 'gCodeImage-${gCode.hashCode}',
              child: buildLeading(gCode, ref.watch(previewImageUriProvider),
                  ref.watch(previewImageHttpHeaderProvider)),
            )),
        title: Text(gCode.name),
        subtitle: Text((lastPrinted != null)
            ? '${tr('pages.files.last_printed')}: $lastPrinted'
            : tr('pages.files.not_printed')),
        onTap: () => ref.read(filesPageControllerProvider.notifier).onFileTapped(gCode),
      ),
    );
  }

  Widget buildLeading(GCodeFile gCodeFile, Uri? machineUri, Map<String, String> headers) {
    var bigImageUri = gCodeFile.constructBigImageUri(machineUri);

    if (bigImageUri != null) {
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
    } else {
      return const Icon(Icons.insert_drive_file);
    }
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
