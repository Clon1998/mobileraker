import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/files/folder.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_api_response.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_notification_item.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_notification_source_item.dart';
import 'package:mobileraker/data/dto/files/remote_file.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/util/path_utils.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

final filePageProvider = StateProvider.autoDispose<int>((ref) => 0);

final isSearchingProvider = StateProvider.autoDispose<bool>((ref) => false);


final searchTextEditingControllerProvider =
    ChangeNotifierProvider.autoDispose<TextEditingController>(
        (ref) => TextEditingController());

final fileSortModeProvider =
    StateProvider.autoDispose<FileSort>((ref) => FileSort.lastModified);

final filesListControllerProvider =
    StateNotifierProvider.autoDispose<FilesPageController, FilePageState>(
        (ref) => FilesPageController(ref));

class FilesPageController extends StateNotifier<FilePageState> {
  FilesPageController(this.ref) : super(FilePageState.loading()) {
    ref.listen(filePageProvider, (previous, int next) {
      fetchDirectoryData((next == 0) ? ['gcodes'] : ['config'], true);
    }, fireImmediately: true);

    ref.listen(isSearchingProvider, (previous, bool next) {
      _filterAndSortResult();
    });

    ref.listen(fileSortModeProvider, (previous, next) {
      _filterAndSortResult();
    });

    ref.listen(searchTextEditingControllerProvider,
        (previous, TextEditingController next) {
      _filterAndSortResult();
    });

    ref.listen(fileNotificationsSelectedProvider,
        (previous, AsyncValue<FileApiResponse> next) {
      next.whenData(handleFileListChanged);
    });
  }

  AutoDisposeRef ref;

  String get pathAsString => state.path.join('/');

  fetchDirectoryData(
      [List<String> newPath = const ['gcodes'], bool force = false]) async {
    if (state.apiResult.isLoading && !force) {
      return;
    } // Prevent dublicate fetches!
    state = FilePageState.loading(newPath);
    var result = await ref
        .read(fileServiceSelectedProvider)
        .fetchDirectoryInfo(pathAsString, true);
    if (pathAsString != result.folderPath) return;
    state = state.copyWith(apiResult: result);
    _filterAndSortResult();
  }

  _filterAndSortResult() {
    if (state.apiResult.isLoading) return;
    FolderContentWrapper rawContent = state.apiResult.value!;
    List<Folder> folders = rawContent.folders.toList();
    List<RemoteFile> files = rawContent.files.toList();

    String queryTerm =
        ref.read(searchTextEditingControllerProvider).text.toLowerCase();

    if (queryTerm.isNotEmpty && ref.read(isSearchingProvider)) {
      List<String> terms = queryTerm.split(RegExp(r'\W+'));
      folders = folders
          .where((element) =>
              terms.every((t) => element.name.toLowerCase().contains(t)))
          .toList(growable: false);

      files = files
          .where((element) =>
              terms.every((t) => element.name.toLowerCase().contains(t)))
          .toList(growable: false);
    }

    var sortMode = ref.read(fileSortModeProvider);
    if (sortMode.comparatorFolder != null) {
      folders.sort(sortMode.comparatorFolder);
    }
    files.sort(sortMode.comparatorFile);

    state = state.copyWith(
        filteredAndSorted:
            FolderContentWrapper(rawContent.folderPath, folders, files));
  }

  handleFileListChanged(FileApiResponse fileListChangedNotification) {
    FileNotificationItem item = fileListChangedNotification.item;
    var itemWithInLevel = isWithin(pathAsString, item.fullPath);

    FileNotificationSourceItem? srcItem =
        fileListChangedNotification.sourceItem;
    var srcItemWithInLevel = isWithin(pathAsString, srcItem?.fullPath ?? '');

    if (itemWithInLevel != 0 && srcItemWithInLevel != 0) {
      return;
    }

    fetchDirectoryData(state.path);
  }

  enterFolder(Folder folder) {
    List<String> newPath = [...state.path, folder.name];
    fetchDirectoryData(newPath);
  }

  popFolder() {
    List<String> newPath = state.path.toList();
    if (newPath.length > 1) {
      newPath.removeLast();
      fetchDirectoryData(newPath);
    }
  }

  Future<bool> onWillPop() async {
    List<String> newPath = state.path.toList();

    if (ref.read(isSearchingProvider)) {
      ref.read(isSearchingProvider.notifier).state = false;
      return false;
    } else if (newPath.length > 1) {
      newPath.removeLast();
      fetchDirectoryData(newPath);
      return false;
    }
    return true;
  }
}

class FilePageState {
  final List<String> path;
  final AsyncValue<FolderContentWrapper> apiResult;
  final AsyncValue<FolderContentWrapper> filteredAndSorted;

  FilePageState(this.path, this.apiResult, this.filteredAndSorted);

  factory FilePageState.loading([List<String> p = const ['gcodes']]) {
    return FilePageState(
        p, const AsyncValue.loading(), const AsyncValue.loading());
  }

  FilePageState copyWith({
    List<String>? path,
    FolderContentWrapper? apiResult,
    FolderContentWrapper? filteredAndSorted,
  }) {
    return FilePageState(
        path ?? this.path,
        (apiResult != null) ? AsyncValue.data(apiResult) : this.apiResult,
        (filteredAndSorted != null)
            ? AsyncValue.data(filteredAndSorted)
            : this.filteredAndSorted);
  }
}

enum FileSort {
  name('pages.files.name', RemoteFile.nameComparator, Folder.nameComparator),
  lastModified('pages.files.last_mod', RemoteFile.modifiedComparator,
      Folder.modifiedComparator),
  lastPrinted(
      'pages.files.last_printed', GCodeFile.lastPrintedComparator, null);

  const FileSort(this.translation, this.comparatorFile, this.comparatorFolder);

  final String translation;

  final Comparator<RemoteFile>? comparatorFile;
  final Comparator<Folder>? comparatorFolder;
}

//
// class FilesViewModel extends MultipleStreamViewModel
//     with SelectedMachineMixin, KlippyMixin {
//   final _logger = getLogger('FilesViewModel');
//
//   final _dialogService = locator<DialogService>();
//   final _navigationService = locator<NavigationService>();
//   final _snackBarService = locator<SnackbarService>();
//
//   bool isSearching = false;
//
//   int currentPageIndex = 0;
//
//   int currentComparatorIndex = 0;
//
//   final List<Comparator<Folder>?> folderComparators = [
//     (folderA, folderB) => folderB.modified.compareTo(folderA.modified),
//     (folderA, folderB) => folderA.name.compareTo(folderB.name),
//     null,
//   ];
//
//   late final List<Comparator<RemoteFile>?> fileComparators = [
//     _comparatorModified,
//     _comparatorName,
//     _comparatorPrintStart
//   ];
//
//   final RefreshController refreshController =
//       RefreshController(initialRefresh: false);
//
//   final TextEditingController searchEditingController = TextEditingController();
//
//   final StreamController<FolderContentWrapper> _folderContentStreamController =
//       BehaviorSubject<FolderContentWrapper>();
//
//   String get requestedPathAsString => requestedPath.join('/');
//   List<String> requestedPath = [];
//
//   Map<int, List<String>> pageStoredPaths = {};
//
//   @override
//   Map<String, StreamData> get streamsMap => {
//         ...super.streamsMap,
//         _FolderContentStreamKey: StreamData<FolderContentWrapper>(
//             _folderContentStreamController.stream),
//         if (isSelectedMachineReady) ...{
//           _FileNotification:
//               StreamData<FileApiResponse>(fileService.fileNotificationStream)
//         }
//       };
//
//   bool get isFolderContentReady => dataReady(_FolderContentStreamKey);
//
//   FolderContentWrapper get _folderContent => dataMap![_FolderContentStreamKey];
//
//   FolderContentWrapper get folderContent {
//     FolderContentWrapper fullContent = _folderContent;
//     List<Folder> folders = _folderContent.folders.toList(growable: false);
//     List<RemoteFile> files = _folderContent.files.toList(growable: false);
//
//     String queryTerm = searchEditingController.text.toLowerCase();
//
//     if (queryTerm.isNotEmpty && isSearching) {
//       List<String> terms = queryTerm.split(RegExp('\\W+'));
//       // RegExp regExp =
//       //     RegExp(terms.where((element) => element.isNotEmpty).join("|"));
//       folders = folders
//           .where((element) =>
//               terms.every((t) => element.name.toLowerCase().contains(t)))
//           .toList(growable: false);
//
//       files = files
//           .where((element) =>
//               terms.every((t) => element.name.toLowerCase().contains(t)))
//           .toList(growable: false);
//     }
//     var folderComparator = folderComparators[currentComparatorIndex];
//     if (folderComparator != null) folders.sort(folderComparator);
//     files.sort(fileComparators[currentComparatorIndex]);
//
//     return FolderContentWrapper(fullContent.reqPath, folders, files);
//   }
//
//   bool get isSubFolder => folderContent.reqPath.split('/').length > 1;
//
//   String? get curPathToPrinterUrl {
//     if (isSelectedMachineReady) {
//       return '${selectedMachine!.httpUrl}/server/files';
//     }
//     return null;
//   }
//
//   startSearching() {
//     isSearching = true;
//     notifyListeners();
//   }
//
//   stopSearching() {
//     isSearching = false;
//     notifyListeners();
//   }
//
//   resetSearchQuery() {
//     searchEditingController.text = '';
//     notifyListeners();
//   }
//
//   handleFileListChanged(FileApiResponse fileListChangedNotification) {
//     _logger.i('CrntPath: $requestedPathAsString');
//     _logger.i('$fileListChangedNotification');
//
//     FileNotificationItem item = fileListChangedNotification.item;
//     var itemWithInLevel = isWithin(requestedPathAsString, item.fullPath);
//
//     FileNotificationSourceItem? srcItem =
//         fileListChangedNotification.sourceItem;
//     var srcItemWithInLevel =
//         isWithin(requestedPathAsString, srcItem?.fullPath ?? '');
//
//     if (itemWithInLevel != 0 && srcItemWithInLevel != 0) {
//       return;
//     }
//
//     _busyFetchDirectoryData(newPath: requestedPath);
//   }
//
//   initialise() {
//     super.initialise();
//     if (isSelectedMachineReady) _fetchDirectoryData();
//   }
//
//   @override
//   onData(String key, data) {
//     super.onData(key, data);
//     switch (key) {
//       case _FileNotification:
//         handleFileListChanged(data);
//         break;
//       default:
//         break;
//     }
//   }
//
//   onBottomItemTapped(int index) {
//     if (index == currentPageIndex) return;
//
//     if (requestedPath.isNotEmpty)
//       pageStoredPaths[currentPageIndex] = requestedPath;
//     currentPageIndex = index;
//     List<String>? newPath =
//         (pageStoredPaths.containsKey(index)) ? pageStoredPaths[index] : null;
//     currentComparatorIndex = 0;
//     switch (index) {
//       case 0:
//         newPath ??= const ['gcodes'];
//         break;
//       case 1:
//         newPath ??= const ['config'];
//         break;
//       default:
//       // Do nothing
//     }
//
//     _busyFetchDirectoryData(newPath: newPath!);
//   }
//
//   onCreateDirTapped(BuildContext context) async {
//     DialogResponse? dialogResponse = await _dialogService.showCustomDialog(
//         variant: DialogType.renameFile,
//         title: tr('dialogs.create_folder.title'),
//         description: tr('dialogs.create_folder.label'),
//         mainButtonTitle: tr('general.create'),
//         secondaryButtonTitle: MaterialLocalizations.of(context)
//             .cancelButtonLabel
//             .toLowerCase()
//             .titleCase(),
//         data: RenameFileDialogArguments(
//             blocklist: _folderContent.folders
//                 .map((e) => e.name)
//                 .toList(growable: false),
//             initialValue: '',
//             matchPattern: '^[\\w.\\-]+\$'));
//     if (dialogResponse?.confirmed ?? false) {
//       String folderName = dialogResponse!.data;
//
//       setBusyForObject(this, true);
//       notifyListeners();
//       try {
//         await fileService.createDir('$requestedPathAsString/$folderName');
//       } on JRpcError catch (e) {
//         _snackBarService.showCustomSnackBar(
//             variant: SnackbarType.error,
//             duration: const Duration(seconds: 5),
//             title: 'Error',
//             message: 'Could not create folder!\n${e.message}');
//         setBusyForObject(this, false);
//         notifyListeners();
//       }
//     }
//   }
//
//   onDeleteFileTapped(BuildContext context, String fileName) async {
//     var materialLocalizations = MaterialLocalizations.of(context);
//     DialogResponse? dialogResponse =
//         await _dialogService.showConfirmationDialog(
//             title: tr('dialogs.delete_folder.title'),
//             description:
//                 tr('dialogs.delete_file.description', args: [fileName]),
//             dialogPlatform: DialogPlatform.Material,
//             confirmationTitle: materialLocalizations.deleteButtonTooltip,
//             cancelTitle: materialLocalizations.cancelButtonLabel
//                 .toLowerCase()
//                 .titleCase());
//
//     if (dialogResponse?.confirmed ?? false) {
//       setBusyForObject(this, true);
//       notifyListeners();
//       try {
//         await fileService.deleteFile('$requestedPathAsString/$fileName');
//       } on JRpcError catch (e) {
//         _snackBarService.showCustomSnackBar(
//             variant: SnackbarType.error,
//             duration: const Duration(seconds: 5),
//             title: 'Error',
//             message: 'Could not perform rename.\n${e.message}');
//         setBusyForObject(this, false);
//         notifyListeners();
//       }
//     }
//   }
//
//   onDeleteDirTapped(BuildContext context, String fileName) async {
//     var materialLocalizations = MaterialLocalizations.of(context);
//     DialogResponse? dialogResponse =
//         await _dialogService.showConfirmationDialog(
//             title: tr('dialogs.delete_folder.title'),
//             description:
//                 tr('dialogs.delete_folder.description', args: [fileName]),
//             dialogPlatform: DialogPlatform.Material,
//             confirmationTitle: materialLocalizations.deleteButtonTooltip,
//             cancelTitle: materialLocalizations.cancelButtonLabel
//                 .toLowerCase()
//                 .titleCase());
//
//     if (dialogResponse?.confirmed ?? false) {
//       setBusyForObject(this, true);
//       notifyListeners();
//       try {
//         await fileService.deleteDirForced('$requestedPathAsString/$fileName');
//       } on JRpcError catch (e) {
//         _snackBarService.showCustomSnackBar(
//             variant: SnackbarType.error,
//             duration: const Duration(seconds: 5),
//             title: 'Error',
//             message: 'Could not perform rename.\n${e.message}');
//         setBusyForObject(this, false);
//         notifyListeners();
//       }
//     }
//   }
//
//   onRenameFileTapped(BuildContext context, String fileName) async {
//     List<String> fileNames = [];
//     fileNames.addAll(_folderContent.folders.map((e) => e.name));
//     fileNames.addAll(_folderContent.files.map((e) => e.name));
//     fileNames.remove(fileName);
//
//     DialogResponse? dialogResponse = await _dialogService.showCustomDialog(
//         variant: DialogType.renameFile,
//         title: tr('dialogs.rename_file.title'),
//         description: tr('dialogs.rename_file.label'),
//         mainButtonTitle: tr('general.rename'),
//         secondaryButtonTitle: MaterialLocalizations.of(context)
//             .cancelButtonLabel
//             .toLowerCase()
//             .titleCase(),
//         data: RenameFileDialogArguments(
//             initialValue: fileName,
//             blocklist: fileNames,
//             fileExt: currentPageIndex == 0 ? 'gcode' : 'cfg',
//             matchPattern: '^[\\w.#+_\\- ]+\$'));
//     if (dialogResponse != null && dialogResponse.confirmed) {
//       String newName = dialogResponse.data;
//       if (newName == fileName) return;
//       setBusyForObject(this, true);
//       notifyListeners();
//       try {
//         await fileService.moveFile('$requestedPathAsString/$fileName',
//             '$requestedPathAsString/$newName');
//       } on JRpcError catch (e) {
//         _snackBarService.showCustomSnackBar(
//             variant: SnackbarType.error,
//             duration: const Duration(seconds: 5),
//             title: 'Error',
//             message: 'Could not perform rename.\n${e.message}');
//         setBusyForObject(this, false);
//         notifyListeners();
//       }
//     }
//   }
//
//   onRenameDirTapped(BuildContext context, String fileName) async {
//     List<String> fileNames = [];
//     fileNames.addAll(_folderContent.folders.map((e) => e.name));
//     fileNames.addAll(_folderContent.files.map((e) => e.name));
//     fileNames.remove(fileName);
//
//     DialogResponse? dialogResponse = await _dialogService.showCustomDialog(
//         variant: DialogType.renameFile,
//         title: tr('dialogs.rename_folder.title'),
//         description: tr('dialogs.rename_folder.label'),
//         mainButtonTitle: tr('general.rename'),
//         secondaryButtonTitle: MaterialLocalizations.of(context)
//             .cancelButtonLabel
//             .toLowerCase()
//             .titleCase(),
//         data: RenameFileDialogArguments(
//             initialValue: fileName,
//             blocklist: fileNames,
//             matchPattern: '^[\\w.\-]+\$'));
//     if (dialogResponse?.confirmed ?? false) {
//       String newName = dialogResponse!.data;
//       if (newName == fileName) return;
//       setBusyForObject(this, true);
//       notifyListeners();
//       try {
//         await fileService.moveFile('$requestedPathAsString/$fileName',
//             '$requestedPathAsString/$newName');
//       } on JRpcError catch (e) {
//         _snackBarService.showCustomSnackBar(
//             variant: SnackbarType.error,
//             duration: const Duration(seconds: 5),
//             title: 'Error',
//             message: 'Could not perform rename.\n${e.message}');
//         setBusyForObject(this, false);
//         notifyListeners();
//       }
//     }
//   }
//
//   onRefresh() {
//     _busyFetchDirectoryData(newPath: folderContent.reqPath.split('/'))
//         .then((value) => refreshController.refreshCompleted());
//   }
//
//   onFileTapped(RemoteFile file) {
//     if (file is GCodeFile)
//       _navigationService.navigateTo(Routes.gCodeFileDetailView,
//           arguments: GCodeFileDetailViewArguments(gcodeFile: file));
//     else
//       _navigationService.navigateTo(Routes.configFileDetailView,
//           arguments: ConfigFileDetailViewArguments(file: file));
//   }
//
//   onFolderPressed(Folder folder) {
//     List<String> newPath = folderContent.reqPath.split('/');
//     newPath.add(folder.name);
//     _busyFetchDirectoryData(newPath: newPath);
//   }
//
//   onBreadCrumbItemPressed(List<String> newPath) {
//     return _busyFetchDirectoryData(newPath: newPath);
//   }
//
//   Future<bool> onWillPop() async {
//     List<String> newPath = folderContent.reqPath.split('/');
//
//     if (isSearching) {
//       stopSearching();
//       return false;
//     } else if (newPath.length > 1 && !isBusy) {
//       newPath.removeLast();
//       _busyFetchDirectoryData(newPath: newPath);
//       return false;
//     }
//     return true;
//   }
//
//   onPopFolder() {
//     List<String> newPath = folderContent.reqPath.split('/');
//     if (newPath.length > 1 && !isBusy) {
//       newPath.removeLast();
//       _busyFetchDirectoryData(newPath: newPath);
//       return false;
//     }
//     return true;
//   }
//
//   onSortSelected(int index) {
//     currentComparatorIndex = index;
//     notifyListeners();
//   }
//
//   int _comparatorName(RemoteFile a, RemoteFile b) => a.name.compareTo(b.name);
//
//   int _comparatorModified(RemoteFile a, RemoteFile b) =>
//       b.modified.compareTo(a.modified);
//
//   int _comparatorPrintStart(RemoteFile fileA, RemoteFile fileB) {
//     GCodeFile a = fileA as GCodeFile;
//     GCodeFile b = fileB as GCodeFile;
//     return b.printStartTime?.compareTo(a.printStartTime ?? 0) ?? -1;
//   }
//
//   Future _fetchDirectoryData({List<String> newPath = const ['gcodes']}) {
//     requestedPath = newPath;
//     return _folderContentStreamController.addStream(
//         fileService.fetchDirectoryInfo(requestedPathAsString, true).asStream());
//   }
//
//   Future _busyFetchDirectoryData({List<String> newPath = const ['gcodes']}) {
//     return runBusyFuture(_fetchDirectoryData(newPath: newPath));
//   }
//
//   @override
//   dispose() {
//     super.dispose();
//     refreshController.dispose();
//     searchEditingController.dispose();
//   }
// }
