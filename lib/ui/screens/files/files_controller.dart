/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/files/folder.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_action_response.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_item.dart';
import 'package:mobileraker/data/dto/files/remote_file_mixin.dart';
import 'package:mobileraker/data/dto/job_queue/job_queue_status.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/job_queue_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mobileraker/ui/components/dialog/rename_file_dialog.dart';
import 'package:mobileraker/ui/screens/files/components/file_sort_mode_selector_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/extensions/ref_extension.dart';
import 'package:mobileraker/util/path_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'files_controller.freezed.dart';
part 'files_controller.g.dart';

final searchTextEditingControllerProvider =
    ChangeNotifierProvider.autoDispose<TextEditingController>((ref) {
  var textEditingController = TextEditingController();
  return textEditingController;
});

@riverpod
class FilePage extends _$FilePage {
  @override
  int build() {
    return 0;
  }

  void onPageTapped(int index) => state = index;
}

@riverpod
class IsSearching extends _$IsSearching {
  @override
  bool build() {
    return false;
  }

  void toggle() => state = !state;
}

@riverpod
class _FilePath extends _$FilePath {
  @override
  List<String> build() {
    var baseDir = ref.watch(filePageProvider
        .select((value) => switch (value) { 1 => 'config', 2 => 'logs', _ => 'gcodes' }));
    return [baseDir];
  }

  update(List<String> newPath) => state = newPath;
}

@riverpod
Future<FolderContentWrapper> _fileApiResponse(_FileApiResponseRef ref, [String path = 'gcodes']) {
  return ref.read(fileServiceSelectedProvider).fetchDirectoryInfo(path, true);
}

@riverpod
Future<FolderContentWrapper> _procssedContent(_ProcssedContentRef ref) async {
  final path = ref.watch(_filePathProvider);
  final fileApiResponse = await ref.watch(_fileApiResponseProvider(path.join('/')).future);
  final searchTerm = ref.watch(searchTextEditingControllerProvider).text.toLowerCase();
  final isSearching = ref.watch(isSearchingProvider);
  final sortMode = ref.watch(fileSortControllerProvider);

  List<Folder> folders = fileApiResponse.folders.toList();
  List<RemoteFile> files = fileApiResponse.files.toList();

  if (isSearching && searchTerm.isNotEmpty) {
    List<String> terms = searchTerm.split(RegExp(r'\W+'));
    folders = folders
        .where((element) => terms.every((t) => element.name.toLowerCase().contains(t)))
        .toList(growable: false);

    files = files
        .where((element) => terms.every((t) => element.name.toLowerCase().contains(t)))
        .toList(growable: false);
  }

  folders.sort(sortMode.comparatorFile);
  files.sort(sortMode.comparatorFile);

  return FolderContentWrapper(fileApiResponse.folderPath, folders, files);
}

@riverpod
class FilesPageController extends _$FilesPageController {
  DialogService get _dialogService => ref.read(dialogServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  FileService get _fileService => ref.read(fileServiceSelectedProvider);

  GoRouter get _goRouter => ref.read(goRouterProvider);

  List<String> get _usedFileNames {
    var folderContentWrapper = ref.read(_fileApiResponseProvider(state.pathAsString)).value!;
    return [
      ...folderContentWrapper.folders,
      ...folderContentWrapper.files,
    ].map((e) => e.name).toList();
  }

  @override
  FilePageState build() {
    ref.keepAliveExternally(fileServiceSelectedProvider);
    ref.listen(fileNotificationsSelectedProvider,
        (previous, AsyncValue<FileActionResponse> next) => next.whenData(_onFileListChanged));

    final path = ref.watch(_filePathProvider);

    var apiLoading =
        ref.watch(_fileApiResponseProvider(path.join('/')).select((value) => value.isLoading));

    final files = ref.watch(_procssedContentProvider);

    return FilePageState(
      path: path,
      files: apiLoading ? files.toLoading() : files,
    );
  }

  refreshFiles() {
    ref.invalidate(_fileApiResponseProvider(state.pathAsString));
  }

  goToPath(List<String> path) {
    ref.read(_filePathProvider.notifier).update(path);
  }

  enterFolder(Folder folder) {
    ref.read(_filePathProvider.notifier).update([...state.path, folder.name]);
  }

  popFolder() {
    var tmp = [...state.path];
    if (tmp.length > 1) {
      tmp.removeLast();
      ref.read(_filePathProvider.notifier).update(tmp);
    }
  }

  Future<bool> onWillPop() async {
    if (ref.read(isSearchingProvider)) {
      ref.read(isSearchingProvider.notifier).toggle();
      return false;
    } else if (state.path.length > 1) {
      var tmp = [...state.path];
      tmp.removeLast();
      ref.read(_filePathProvider.notifier).update(tmp);
      return false;
    }
    return true;
  }

  onDeleteTapped(RemoteFile file) async {
    var dialogResponse = await _dialogService.showConfirm(
      title: tr('dialogs.delete_folder.title'),
      body: tr(
          file is Folder ? 'dialogs.delete_folder.description' : 'dialogs.delete_file.description',
          args: [file.name]),
      confirmBtn: tr('general.delete'),
    );

    if (dialogResponse?.confirmed == true) {
      // state = FilePageState.loading(state.path);
      state = state.copyWith(files: state.files.toLoading());
      try {
        if (file is Folder) {
          await _fileService.deleteDirForced('${state.pathAsString}/${file.name}');
        } else {
          await _fileService.deleteFile('${state.pathAsString}/${file.name}');
        }
      } on JRpcError catch (e) {
        _snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          message: 'Could not delete File.\n${e.message}',
        ));
      }
    }
  }

  onRenameTapped(RemoteFile file) async {
    var fileNames = _usedFileNames;
    fileNames.remove(file.name);

    var dialogResponse = await _dialogService.show(
      DialogRequest(
          type: DialogType.renameFile,
          title:
              file is Folder ? tr('dialogs.rename_folder.title') : tr('dialogs.rename_file.title'),
          body:
              file is Folder ? tr('dialogs.rename_folder.label') : tr('dialogs.rename_file.label'),
          confirmBtn: tr('general.rename'),
          data: RenameFileDialogArguments(
            initialValue: file.name,
            blocklist: fileNames,
            matchPattern: '^[\\w.-]+\$',
          )),
    );

    if (dialogResponse?.confirmed == true) {
      state = state.copyWith(files: state.files.toLoading());
      String newName = dialogResponse!.data;
      if (newName == file.name) return;

      try {
        await _fileService.moveFile(
            '${state.pathAsString}/${file.name}', '${state.pathAsString}/$newName');
      } on JRpcError catch (e) {
        logger.e('Could not perform rename.', e);
        _snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          message: 'Could not rename File.\n${e.message}',
        ));
      }
    }
  }

  //
  // onAddToQueueTapped(GCodeFile file) async {
  //   try {
  //     await _fileService.moveFile('$pathAsString/${file.name}', '$pathAsString/$newName');
  //   } on JRpcError catch (e) {
  //     _snackBarService.show(SnackBarConfig(
  //       type: SnackbarType.error,
  //       message: 'Could not add File to Queue.\n${e.message}',
  //     ));
  //   } finally {
  //     fetchDirectoryData(state.path, true);
  //   }
  // }

  onCreateDirTapped() async {
    var dialogResponse = await _dialogService.show(
      DialogRequest(
          type: DialogType.renameFile,
          title: tr('dialogs.create_folder.title'),
          body: tr('dialogs.create_folder.label'),
          confirmBtn: tr('general.create'),
          data: RenameFileDialogArguments(
              initialValue: '', blocklist: _usedFileNames, matchPattern: '^[\\w.\\-]+\$')),
    );

    if (dialogResponse?.confirmed == true) {
      state = state.copyWith(files: state.files.toLoading());
      String newName = dialogResponse!.data;

      try {
        await _fileService.createDir('${state.pathAsString}/$newName');
      } on JRpcError catch (e) {
        // _snackBarService.showCustomSnackBar(
        //     variant: SnackbarType.error,
        //     duration: const Duration(seconds: 5),
        //     title: 'Error',
        //     message: 'Could not create folder!\n${e.message}');
      }
    }
  }

  onFileTapped(RemoteFile file) {
    if (file is GCodeFile) {
      _goRouter.goNamed(AppRoute.gcodeDetail.name, extra: file);
    } else {
      _goRouter.goNamed(AppRoute.configDetail.name, extra: file);
    }
  }

  _onFileListChanged(FileActionResponse fileListChangedNotification) {
    logger.i('FileListChangedNotification: $fileListChangedNotification');
    FileItem item = fileListChangedNotification.item;
    var itemWithInLevel = isWithin(state.pathAsString, item.fullPath);

    FileItem? srcItem = fileListChangedNotification.sourceItem;
    var srcItemWithInLevel = isWithin(state.pathAsString, srcItem?.fullPath ?? '');

    if (itemWithInLevel != 0 && srcItemWithInLevel != 0) {
      return;
    }

    ref.invalidate(_fileApiResponseProvider(state.pathAsString));
  }
}
//
// class FilesPageController extends StateNotifier<FilePageState> {
//   FilesPageController(this.ref)
//       : _snackBarService = ref.watch(snackBarServiceProvider),
//         _jobQueueService = ref.watch(jobQueueServiceSelectedProvider),
//         super(FilePageState.loading()) {
//
//   }
//
//   final AutoDisposeRef ref;
//   final SnackBarService _snackBarService;
//   final JobQueueService _jobQueueService;
//   final FileService _fileService;
//
//   String get pathAsString => state.path.join('/');
//
//   fetchDirectoryData([List<String> newPath = const ['gcodes'], bool force = false]) async {
//     try {
//       if (state.apiResult.isLoading && !force) {
//         return;
//       } // Prevent dublicate fetches!
//       state = FilePageState.loading(newPath);
//       var result =
//           await ref.read(fileServiceSelectedProvider).fetchDirectoryInfo(pathAsString, true);
//       if (pathAsString != result.folderPath) return;
//       state = state.copyWith(apiResult: result);
//       _filterAndSortResult();
//     } catch (e, s) {
//       state = FilePageState(newPath, AsyncValue.error(e, s), AsyncValue.error(e, s));
//     }
//   }
//
//   _filterAndSortResult() {
//     if (state.apiResult.isLoading) return;
//     FolderContentWrapper rawContent = state.apiResult.value!;
//     List<Folder> folders = rawContent.folders.toList();
//     List<RemoteFile> files = rawContent.files.toList();
//     String queryTerm = ref.read(searchTextEditingControllerProvider).text.toLowerCase();
//
//     if (queryTerm.isNotEmpty && ref.read(isSearchingProvider)) {
//       List<String> terms = queryTerm.split(RegExp(r'\W+'));
//       folders = folders
//           .where((element) => terms.every((t) => element.name.toLowerCase().contains(t)))
//           .toList(growable: false);
//
//       files = files
//           .where((element) => terms.every((t) => element.name.toLowerCase().contains(t)))
//           .toList(growable: false);
//     }
//
//     var sortMode = ref.read(fileSortControllerProvider);
//     folders.sort(sortMode.comparatorFile);
//     files.sort(sortMode.comparatorFile);
//
//     state = state.copyWith(
//         filteredAndSorted: FolderContentWrapper(rawContent.folderPath, folders, files));
//   }
//
//   handleFileListChanged(FileActionResponse fileListChangedNotification) {
//     FileItem item = fileListChangedNotification.item;
//     var itemWithInLevel = isWithin(pathAsString, item.fullPath);
//
//     FileItem? srcItem = fileListChangedNotification.sourceItem;
//     var srcItemWithInLevel = isWithin(pathAsString, srcItem?.fullPath ?? '');
//
//     if (itemWithInLevel != 0 && srcItemWithInLevel != 0) {
//       return;
//     }
//
//     fetchDirectoryData(state.path);
//   }
//
//   enterFolder(Folder folder) {
//     List<String> newPath = [...state.path, folder.name];
//     fetchDirectoryData(newPath);
//   }
//
//   popFolder() {
//     List<String> newPath = state.path.toList();
//     if (newPath.length > 1) {
//       newPath.removeLast();
//       fetchDirectoryData(newPath);
//     }
//   }
//
//   Future<bool> onWillPop() async {
//     List<String> newPath = state.path.toList();
//
//     if (ref.read(isSearchingProvider)) {
//       ref.read(isSearchingProvider.notifier).state = false;
//       return false;
//     } else if (newPath.length > 1) {
//       newPath.removeLast();
//       fetchDirectoryData(newPath);
//       return false;
//     }
//     return true;
//   }
//
//   onDeleteTapped(RemoteFile file) async {
//     var dialogResponse = await ref.read(dialogServiceProvider).showConfirm(
//           title: tr('dialogs.delete_folder.title'),
//           body: tr(
//               file is Folder
//                   ? 'dialogs.delete_folder.description'
//                   : 'dialogs.delete_file.description',
//               args: [file.name]),
//           confirmBtn: tr('general.delete'),
//         );
//
//     if (dialogResponse?.confirmed == true) {
//       state = FilePageState.loading(state.path);
//       try {
//         if (file is Folder) {
//           await ref.read(fileServiceSelectedProvider).deleteDirForced('$pathAsString/${file.name}');
//         } else {
//           await ref.read(fileServiceSelectedProvider).deleteFile('$pathAsString/${file.name}');
//         }
//       } on JRpcError catch (e) {
//         _snackBarService.show(SnackBarConfig(
//           type: SnackbarType.error,
//           message: 'Could not delete File.\n${e.message}',
//         ));
//       } finally {
//         fetchDirectoryData(state.path, true);
//       }
//     }
//   }
//
//   onRenameTapped(RemoteFile file) async {
//     var folderContentWrapper = state.apiResult.value!;
//     List<String> fileNames = [
//       ...folderContentWrapper.folders,
//       ...folderContentWrapper.files,
//     ].map((e) => e.name).toList();
//     fileNames.remove(file.name);
//
//     var dialogResponse = await ref.read(dialogServiceProvider).show(
//           DialogRequest(
//               type: DialogType.renameFile,
//               title: file is Folder
//                   ? tr('dialogs.rename_folder.title')
//                   : tr('dialogs.rename_file.title'),
//               body: file is Folder
//                   ? tr('dialogs.rename_folder.label')
//                   : tr('dialogs.rename_file.label'),
//               confirmBtn: tr('general.rename'),
//               data: RenameFileDialogArguments(
//                 initialValue: file.name,
//                 blocklist: fileNames,
//                 matchPattern: '^[\\w.-]+\$',
//               )),
//         );
//
//     if (dialogResponse?.confirmed == true) {
//       state = FilePageState.loading(state.path);
//       String newName = dialogResponse!.data;
//       if (newName == file.name) return;
//
//       try {
//         await ref
//             .read(fileServiceSelectedProvider)
//             .moveFile('$pathAsString/${file.name}', '$pathAsString/$newName');
//       } on JRpcError catch (e) {
//         logger.e('Could not perform rename.', e);
//         _snackBarService.show(SnackBarConfig(
//           type: SnackbarType.error,
//           message: 'Could not rename File.\n${e.message}',
//         ));
//       } finally {
//         fetchDirectoryData(state.path, true);
//       }
//     }
//   }
//
//   onAddToQueueTapped(GCodeFile file) async {
//     try {
//       await ref
//           .read(fileServiceSelectedProvider)
//           .moveFile('$pathAsString/${file.name}', '$pathAsString/$newName');
//     } on JRpcError catch (e) {
//       _snackBarService.show(SnackBarConfig(
//         type: SnackbarType.error,
//         message: 'Could not add File to Queue.\n${e.message}',
//       ));
//     } finally {
//       fetchDirectoryData(state.path, true);
//     }
//   }
//
//   onCreateDirTapped() async {
//     if (state.apiResult.isLoading) return;
//
//     var dialogResponse = await ref.read(dialogServiceProvider).show(
//           DialogRequest(
//               type: DialogType.renameFile,
//               title: tr('dialogs.create_folder.title'),
//               body: tr('dialogs.create_folder.label'),
//               confirmBtn: tr('general.create'),
//               data: RenameFileDialogArguments(
//                   initialValue: '',
//                   blocklist:
//                       state.apiResult.value!.folders.map((e) => e.name).toList(growable: false),
//                   matchPattern: '^[\\w.\\-]+\$')),
//         );
//
//     if (dialogResponse?.confirmed == true) {
//       state = FilePageState.loading(state.path);
//       String newName = dialogResponse!.data;
//
//       try {
//         await ref.read(fileServiceSelectedProvider).createDir('$pathAsString/$newName');
//       } on JRpcError catch (e) {
//         // _snackBarService.showCustomSnackBar(
//         //     variant: SnackbarType.error,
//         //     duration: const Duration(seconds: 5),
//         //     title: 'Error',
//         //     message: 'Could not create folder!\n${e.message}');
//       } finally {
//         fetchDirectoryData(state.path, true);
//       }
//     }
//   }
//
//   onFileTapped(RemoteFile file) {
//     if (file is GCodeFile) {
//       ref.read(goRouterProvider).goNamed(AppRoute.gcodeDetail.name, extra: file);
//     } else {
//       ref.read(goRouterProvider).goNamed(AppRoute.configDetail.name, extra: file);
//     }
//   }
// }

@freezed
class FilePageState with _$FilePageState {
  const FilePageState._();

  const factory FilePageState({
    required List<String> path,
    required AsyncValue<FolderContentWrapper> files,
  }) = _FilePageState;

  bool get isInSubFolder => path.length > 1;

  String get pathAsString => path.join('/');
}
