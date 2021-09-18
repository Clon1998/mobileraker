import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/dto/files/folder.dart';
import 'package:mobileraker/dto/files/gcode_file.dart';
import 'package:mobileraker/service/file_service.dart';
import 'package:mobileraker/ui/components/connection/connection_state_view.dart';
import 'package:mobileraker/ui/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/views/files/files_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';
import 'package:stacked/stacked.dart';

class FilesView extends ViewModelBuilderWidget<FilesViewModel> {
  const FilesView({Key? key}) : super(key: key);

  @override
  Widget builder(BuildContext context, FilesViewModel model, Widget? child) {
    return WillPopScope(
      onWillPop: model.onPopFolder,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'File Browser',
            overflow: TextOverflow.fade,
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () => null,
            ),
            IconButton(
              icon: Icon(
                Icons.sort,
              ),
              onPressed: () => null,
            ),
          ],
        ),
        drawer: NavigationDrawerWidget(curPath: Routes.filesView),
        body: ConnectionStateView(
          pChild: buildBody(context, model),
        ),
      ),
    );
  }

  Widget buildBody(BuildContext context, FilesViewModel model) {
    if (model.isBusy)
      return buildBusyListView(context, model);
    else if (model.hasFolderContent)
      return buildListView(context, model);
    else
      return buildFetchingView();
  }

  Center buildFetchingView() {
    return Center(
      child: Column(
        key: UniqueKey(),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitSpinningLines(
            color: Colors.orange,
          ),
          SizedBox(
            height: 30,
          ),
          FadingText("Fetching files..."),
          // Text("Fetching printer ...")
        ],
      ),
    );
  }

  Container buildBusyListView(BuildContext context, FilesViewModel model) {
    ThemeData theme = Theme.of(context);
    Color highlightColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.secondary
        : theme.primaryColor;
    return Container(
      margin: const EdgeInsets.all(4.0),
      color: theme.colorScheme.background,
      child: Column(
        children: [
          buildBreadCrumb(context, model.requestedPath),
          Expanded(
            child: Shimmer.fromColors(
              child: ListView.builder(
                  itemCount: 15,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Container(
                        width: 64,
                        height: 64,
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                      ),
                      title: Container(
                        width: double.infinity,
                        height: 16.0,
                        color: Colors.white,
                      ),
                    );
                  }),
              baseColor: Colors.grey,
              highlightColor: highlightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildListView(BuildContext context, FilesViewModel model) {
    FolderReqWrapper folderContent = model.folderContent;

    int lenFolders = folderContent.folders.length;
    int lenGcodes = folderContent.gCodes.length;
    int lenTotal = lenFolders + lenGcodes;
    // Add one of the .. folder to back
    if (model.isSubFolder) lenTotal++;

    ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(4.0),
      color: theme.colorScheme.background,
      child: Column(
        children: [
          buildBreadCrumb(context, model.folderContent.reqPath.split('/')),
          Expanded(
            child: SmartRefresher(
              controller: model.refreshController,
              onRefresh: model.onRefresh,
              child: ListView.builder(
                  itemCount: lenTotal,
                  itemBuilder: (context, index) {
                    if (model.isSubFolder) {
                      if (index == 0)
                        return ListTile(
                          leading: SizedBox(
                              width: 64, height: 64, child: Icon(Icons.folder)),
                          title: Text("..."),
                          onTap: () => model.onPopFolder(),
                        );
                      else
                        index--;
                    }

                    if (index < lenFolders) {
                      Folder folder = folderContent.folders[index];
                      return FolderItem(folder: folder);
                    } else {
                      GCodeFile file = folderContent.gCodes[index - lenFolders];
                      return FileItem(gCode: file);
                    }
                  }),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBreadCrumb(BuildContext context, List<String> paths) {
    ThemeData theme = Theme.of(context);
    Color highlightColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: highlightColor,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: BreadCrumb.builder(
          itemCount: paths.length,
          builder: (index) {
            String p = paths[index];
            return BreadCrumbItem(
                content: Text(
                  '${p.toUpperCase()}',
                  style: theme.textTheme.subtitle1,
                ),
                onTap: () => print('TAPED$p'));
          },
          divider: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              '/',
              style: theme.textTheme.subtitle1,
            ),
          ),
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
    return ListTile(
      leading: SizedBox(width: 64, height: 64, child: Icon(Icons.folder)),
      title: Text(folder.name),
      onTap: () => model.onFolderPressed(folder),
    );
  }
}

class FileItem extends ViewModelWidget<FilesViewModel> {
  final GCodeFile gCode;

  const FileItem({Key? key, required this.gCode}) : super(key: key);

  @override
  Widget build(BuildContext context, FilesViewModel model) {
    return ListTile(
      leading: SizedBox(
          width: 64,
          height: 64,
          child: buildLeading(gCode, model.curPathToPrinterUrl)),
      title: Text(gCode.name),
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
        child: CachedNetworkImage(
          imageUrl: '$printerUrl/${gCode.parentPath}/${gCode.smallImagePath}',
          placeholder: (context, url) => Icon(Icons.insert_drive_file),
          errorWidget: (context, url, error) => Icon(Icons.error),
        ),
      );
    else
      return Icon(Icons.insert_drive_file);
  }
}
