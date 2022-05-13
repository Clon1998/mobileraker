import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/dto/files/remote_file.dart';
import 'package:mobileraker/data/dto/files/folder.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/components/ease_in.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/views/files/files_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shimmer/shimmer.dart';
import 'package:stacked/stacked.dart';

class FilesView extends ViewModelBuilderWidget<FilesViewModel> {
  const FilesView({Key? key}) : super(key: key);

  @override
  Widget builder(BuildContext context, FilesViewModel model, Widget? child) {
    return WillPopScope(
      onWillPop: model.onWillPop,
      child: Scaffold(
        appBar: buildAppBar(context, model),
        drawer: NavigationDrawerWidget(curPath: Routes.filesView),
        bottomNavigationBar: BottomNavigationBar(
          showSelectedLabels: true,
          currentIndex: model.currentPageIndex,
          onTap: model.onBottomItemTapped,
          items: [
            BottomNavigationBarItem(
                label: 'GCodes',
                icon: Icon(FlutterIcons.printer_3d_nozzle_outline_mco)),
            BottomNavigationBarItem(
                label: 'Configs', icon: Icon(FlutterIcons.file_code_faw5)),
          ],
        ),
        body: ConnectionStateView(
          onConnected: buildBody(context, model),
        ),
      ),
    );
  }

  AppBar buildAppBar(BuildContext context, FilesViewModel model) {
    var themeData = Theme.of(context);

    var onBackground = themeData.appBarTheme.foregroundColor ??
        (themeData.colorScheme.brightness == Brightness.dark
            ? themeData.colorScheme.onSurface
            : themeData.colorScheme.onPrimary);

    if (model.isSearching) {
      return AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: model.stopSearching,
        ),
        title: EaseIn(
          child: TextField(
            onChanged: (str) => model.notifyListeners(),
            controller: model.searchEditingController,
            autofocus: true,
            style: themeData.textTheme.headline6?.copyWith(color: onBackground),
            decoration: InputDecoration(
              hintText: '${tr('pages.files.search_files')}...',
              hintStyle: themeData.textTheme.headline6
                  ?.copyWith(color: onBackground.withOpacity(0.5)),
              border: InputBorder.none,
              suffixIcon: model.searchEditingController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'pages.files.clear_search'.tr(),
                      icon: Icon(Icons.close),
                      color: onBackground,
                      onPressed: model.resetSearchQuery,
                    ),
            ),
          ),
        ),
      );
    } else
      return AppBar(
        title: Text(
          'pages.files.title',
          overflow: TextOverflow.fade,
        ).tr(),
        actions: <Widget>[
          //TODO: Rework this properly...
          PopupMenuButton(
            icon: Icon(
              Icons.sort,
            ),
            onSelected: model.onSortSelected,
            itemBuilder: (BuildContext context) => [
              CheckedPopupMenuItem(
                child: Text('pages.files.last_mod').tr(),
                value: 0,
                checked: model.currentComparatorIndex == 0,
              ),
              CheckedPopupMenuItem(
                child: Text('pages.files.name').tr(),
                value: 1,
                checked: model.currentComparatorIndex == 1,
              ),
              if (model.currentPageIndex == 0)
                CheckedPopupMenuItem(
                  child: Text('pages.files.last_printed').tr(),
                  value: 2,
                  checked: model.currentComparatorIndex == 2,
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: model.startSearching,
          ),
        ],
      );
  }

  Widget buildBody(BuildContext context, FilesViewModel model) {
    if (model.isBusy)
      return buildBusyListView(context, model);
    else if (model.isFolderContentAvailable &&
        model.isServerAvailable &&
        model.isMachineAvailable)
      return buildListView(context, model);
    else
      return buildFetchingView(context);
  }

  Center buildFetchingView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitRipple(
            color: Theme.of(context).colorScheme.secondary,
            size: 100,
          ),
          SizedBox(
            height: 30,
          ),
          FadingText(tr('pages.files.fetching_files')),
          // Text('Fetching printer ...')
        ],
      ),
    );
  }

  Widget buildBusyListView(BuildContext context, FilesViewModel model) {
    ThemeData theme = Theme.of(context);
    Color highlightColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.background
        : theme.colorScheme.background;
    return _buildListViewContainer(
        context,
        Column(
          children: [
            buildBreadCrumb(context, model, model.requestedPath),
            Expanded(
              child: Shimmer.fromColors(
                child: ListView.builder(
                    itemCount: 15,
                    itemBuilder: (context, index) {
                      return ListTile(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                          margin: EdgeInsets.only(right: 5),
                          color: Colors.white,
                        ),
                      );
                    }),
                baseColor: Colors.grey,
                highlightColor: highlightColor,
              ),
            ),
          ],
        ));
  }

  Widget buildListView(BuildContext context, FilesViewModel model) {
    FolderContentWrapper folderContent = model.folderContent;

    int lenFolders = folderContent.folders.length;
    int lenGcodes = folderContent.files.length;
    int lenTotal = lenFolders + lenGcodes;
    // Add one of the .. folder to back
    if (model.isSubFolder) lenTotal++;

    return _buildListViewContainer(
        context,
        Column(
          children: [
            buildBreadCrumb(
                context, model, model.folderContent.reqPath.split('/')),
            Expanded(
              child: EaseIn(
                duration: Duration(milliseconds: 100),
                child: SmartRefresher(
                  controller: model.refreshController,
                  onRefresh: model.onRefresh,
                  child: (lenTotal == 0)
                      ? ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                              width: 64,
                              height: 64,
                              child: Icon(Icons.search_off)),
                          title: Text('pages.files.no_files_found').tr(),
                        )
                      : ListView.builder(
                          itemCount: lenTotal,
                          itemBuilder: (context, index) {
                            if (model.isSubFolder) {
                              if (index == 0)
                                return ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 3),
                                  leading: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Icon(Icons.folder)),
                                  title: Text('...'),
                                  onTap: () => model.onPopFolder(),
                                );
                              else
                                index--;
                            }

                            if (index < lenFolders) {
                              Folder folder = folderContent.folders[index];
                              return FolderItem(
                                folder: folder,
                                key: ValueKey(folder),
                              );
                            } else {
                              RemoteFile file =
                                  folderContent.files[index - lenFolders];
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
            ),
          ],
        ));
  }

  Widget _buildListViewContainer(BuildContext context, Widget? child) {
    var theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: Colors.grey,
              offset: Offset(0.0, 4.0), //(x,y)
              blurRadius: 1.0,
            ),
        ],
      ),
      child: child,
    );
  }

  Widget buildBreadCrumb(
      BuildContext context, FilesViewModel model, List<String> paths) {
    ThemeData theme = Theme.of(context);
    Color highlightColor = theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: highlightColor,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: BreadCrumb.builder(
                itemCount: paths.length,
                builder: (index) {
                  String p = paths[index];
                  List<String> fullPath = paths.sublist(0, index + 1);
                  return BreadCrumbItem(
                      content: Text(
                        '${p.toUpperCase()}',
                        style: theme.textTheme.subtitle1
                            ?.copyWith(color: theme.colorScheme.onPrimary),
                      ),
                      onTap: () => model.onBreadCrumbItemPressed(fullPath));
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
              padding: EdgeInsets.only(left: 4),
              constraints: BoxConstraints(),
              iconSize: 20,
              color: theme.colorScheme.onPrimary,
              icon: Icon(Icons.create_new_folder_outlined),
              onPressed: () => model.onCreateDirTapped(context),
            )
          ],
        ),
      ),
    );
  }

  @override
  FilesViewModel viewModelBuilder(BuildContext context) => FilesViewModel();
}

class FolderItem extends ViewModelWidget<FilesViewModel> {
  final Folder folder;

  const FolderItem({Key? key, required this.folder}) : super(key: key);

  @override
  Widget build(BuildContext context, FilesViewModel model) {
    return _Slideable(
      fileName: folder.name,
      isFolder: true,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: SizedBox(width: 64, height: 64, child: Icon(Icons.folder)),
        title: Text(folder.name),
        onTap: () => model.onFolderPressed(folder),
      ),
    );
  }
}

class FileItem extends ViewModelWidget<FilesViewModel> {
  final RemoteFile file;

  const FileItem({Key? key, required this.file}) : super(key: key);

  @override
  Widget build(BuildContext context, FilesViewModel model) {
    return _Slideable(
      fileName: file.name,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: SizedBox(
            width: 64, height: 64, child: Icon(Icons.insert_drive_file)),
        title: Text(file.name),
        onTap: () => model.onFileTapped(file),
      ),
    );
  }
}

class GCodeFileItem extends ViewModelWidget<FilesViewModel> {
  final GCodeFile gCode;

  const GCodeFileItem({Key? key, required this.gCode}) : super(key: key);

  @override
  Widget build(BuildContext context, FilesViewModel model) {
    return _Slideable(
      fileName: gCode.name,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        leading: SizedBox(
            width: 64,
            height: 64,
            child: buildLeading(gCode, model.curPathToPrinterUrl)),
        title: Text(gCode.name),
        onTap: () => model.onFileTapped(gCode),
      ),
    );

    // return ListTile(
    //   leading: Icon(Icons.insert_drive_file),
    //   title: Text(gCode.name),
    // );
  }

  Widget buildLeading(GCodeFile gCodeFile, String? printerUrl) {
    if (printerUrl != null && gCodeFile.smallImagePath != null)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Hero(
          tag: 'gCodeImage-${gCodeFile.hashCode}',
          child: CachedNetworkImage(
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.horizontal(
                    left: const Radius.circular(15.0),
                    right: const Radius.circular(15.0)),
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: Offset(-1, 1), // changes position of shadow
                  ),
                ],
              ),
            ),
            imageUrl: '$printerUrl/${gCode.parentPath}/${gCode.bigImagePath}',
            placeholder: (context, url) => Icon(Icons.insert_drive_file),
            errorWidget: (context, url, error) => Icon(Icons.error),
          ),
        ),
      );
    else
      return Icon(Icons.insert_drive_file);
  }
}

class _Slideable extends ViewModelWidget<FilesViewModel> {
  _Slideable(
      {required this.child, required this.fileName, this.isFolder = false});

  final Widget child;
  final String fileName;
  final bool isFolder;

  @override
  Widget build(BuildContext context, FilesViewModel model) {
    var themeData = Theme.of(context);
    return Slidable(
      endActionPane: ActionPane(
        motion: ScrollMotion(),
        children: [
          SlidableAction(
            // An action can be bigger than the others.
            onPressed: (c) => (isFolder)
                ? model.onRenameDirTapped(c, fileName)
                : model.onRenameFileTapped(c, fileName),
            backgroundColor: themeData.colorScheme.secondaryContainer,
            foregroundColor: themeData.colorScheme.onSecondaryContainer,
            icon: Icons.drive_file_rename_outline,
            label: 'Rename',
          ),
          SlidableAction(
            onPressed: (c) => (isFolder)
                ? model.onDeleteDirTapped(c, fileName)
                : model.onDeleteFileTapped(c, fileName),
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
