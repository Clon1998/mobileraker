import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/files/folder.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_api_response.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_notification_item.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_notification_source_item.dart';
import 'package:mobileraker/data/dto/files/remote_file.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/dialog/rename_file_dialog.dart';
import 'package:mobileraker/util/path_utils.dart';

final filePageProvider = StateProvider.autoDispose<int>((ref) => 0);

final isSearchingProvider = StateProvider.autoDispose<bool>((ref) => false);

final searchTextEditingControllerProvider =
    ChangeNotifierProvider.autoDispose<TextEditingController>(
        (ref) {
          var textEditingController = TextEditingController();
          ref.onDispose(textEditingController.dispose);
          return textEditingController;
        });

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

  onDeleteFileTapped(
      MaterialLocalizations materialLocalizations, String fileName) async {
    var dialogResponse = await ref.read(dialogServiceProvider).showConfirm(
          title: tr('dialogs.delete_folder.title'),
          body: tr('dialogs.delete_file.description', args: [fileName]),
          confirmBtn: materialLocalizations.deleteButtonTooltip,
        );

    if (dialogResponse?.confirmed == true) {
      state = FilePageState.loading(state.path);
      try {
        await ref
            .read(fileServiceSelectedProvider)
            .deleteFile('$pathAsString/$fileName');
      } on JRpcError catch (e) {
        //TODO:
        // ref.read(snackBarServiceProvider).show(
        //     variant: SnackbarType.error,
        //     duration: const Duration(seconds: 5),
        //     title: 'Error',
        //     message: 'Could not perform rename.\n${e.message}');
      } finally {
        fetchDirectoryData(state.path, true);
      }
    }
  }

  onDeleteDirTapped(
      MaterialLocalizations materialLocalizations, String folder) async {
    var dialogResponse = await ref.read(dialogServiceProvider).showConfirm(
          title: tr('dialogs.delete_folder.title'),
          body: tr('dialogs.delete_folder.description', args: [folder]),
          confirmBtn: materialLocalizations.deleteButtonTooltip,
        );

    if (dialogResponse?.confirmed == true) {
      state = FilePageState.loading(state.path);
      try {
        await ref
            .read(fileServiceSelectedProvider)
            .deleteDirForced('$pathAsString/$folder');
      } on JRpcError catch (e) {
        //TODO:
        // _snackBarService.showCustomSnackBar(
        //     variant: SnackbarType.error,
        //     duration: const Duration(seconds: 5),
        //     title: 'Error',
        //     message: 'Could not perform rename.\n${e.message}');
      } finally {
        fetchDirectoryData(state.path, true);
      }
    }
  }

  onRenameFileTapped(String fileName) async {
    var folderContentWrapper = state.apiResult.value!;
    List<String> fileNames = [];
    fileNames.addAll(folderContentWrapper.folders.map((e) => e.name));
    fileNames.addAll(folderContentWrapper.files.map((e) => e.name));
    fileNames.remove(fileName);

    var dialogResponse = await ref.read(dialogServiceProvider).show(
          DialogRequest(
              type: DialogType.renameFile,
              title: tr('dialogs.rename_file.title'),
              body: tr('dialogs.rename_file.label'),
              confirmBtn: tr('general.rename'),
              data: RenameFileDialogArguments(
                  initialValue: fileName,
                  blocklist: fileNames,
                  matchPattern: '^[\\w.#+_\\- ]+\$')),
        );

    _handleRenameResult(dialogResponse, fileName);
  }

  onRenameDirTapped(String fileName) async {
    var folderContentWrapper = state.apiResult.value!;
    List<String> fileNames = [];
    fileNames.addAll(folderContentWrapper.folders.map((e) => e.name));
    fileNames.addAll(folderContentWrapper.files.map((e) => e.name));
    fileNames.remove(fileName);

    var dialogResponse = await ref.read(dialogServiceProvider).show(
          DialogRequest(
              type: DialogType.renameFile,
              title: tr('dialogs.rename_folder.title'),
              body: tr('dialogs.rename_folder.label'),
              confirmBtn: tr('general.rename'),
              data: RenameFileDialogArguments(
                  initialValue: fileName,
                  blocklist: fileNames,
                  matchPattern: '^[\\w.-]+\$')),
        );
    _handleRenameResult(dialogResponse, fileName);
  }

  _handleRenameResult(
      DialogResponse? dialogResponse, String originalName) async {
    if (dialogResponse?.confirmed == true) {
      state = FilePageState.loading(state.path);
      String newName = dialogResponse!.data;
      if (newName == originalName) return;

      try {
        await ref
            .read(fileServiceSelectedProvider)
            .moveFile('$pathAsString/$originalName', '$pathAsString/$newName');
      } on JRpcError catch (e) {
        // _snackBarService.showCustomSnackBar(
        //     variant: SnackbarType.error,
        //     duration: const Duration(seconds: 5),
        //     title: 'Error',
        //     message: 'Could not perform rename.\n${e.message}');
      } finally {
        fetchDirectoryData(state.path, true);
      }
    }
  }

  onCreateDirTapped() async {
    if (state.apiResult.isLoading) return;

    var dialogResponse = await ref.read(dialogServiceProvider).show(
          DialogRequest(
              type: DialogType.renameFile,
              title: tr('dialogs.create_folder.title'),
              body: tr('dialogs.create_folder.label'),
              confirmBtn: tr('general.create'),
              data: RenameFileDialogArguments(
                  initialValue: '',
                  blocklist: state.apiResult.value!.folders
                      .map((e) => e.name)
                      .toList(growable: false),
                  matchPattern: '^[\\w.\\-]+\$')),
        );

    if (dialogResponse?.confirmed == true) {
      state = FilePageState.loading(state.path);
      String newName = dialogResponse!.data;

      try {
        await ref
            .read(fileServiceSelectedProvider)
            .createDir('$pathAsString/$newName');
      } on JRpcError catch (e) {
        // _snackBarService.showCustomSnackBar(
        //     variant: SnackbarType.error,
        //     duration: const Duration(seconds: 5),
        //     title: 'Error',
        //     message: 'Could not create folder!\n${e.message}');
      } finally {
        fetchDirectoryData(state.path, true);
      }
    }
  }

  onFileTapped(RemoteFile file) {
    if (file is GCodeFile) {
      ref.read(goRouterProvider).goNamed(AppRoute.gcodeDetail.name, extra: file);
    } else {
      ref.read(goRouterProvider).goNamed(AppRoute.configDetail.name, extra: file);
    }

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
