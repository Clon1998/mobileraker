/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/moonraker/file_action_response.dart';
import 'package:common/data/dto/files/moonraker/file_item.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/dto/job_queue/job_queue_status.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/text_input/text_input_dialog.dart';
import 'package:mobileraker/ui/screens/files/components/file_sort_mode_selector_controller.dart';
import 'package:mobileraker/util/path_utils.dart';
import 'package:mobileraker_pro/service/moonraker/job_queue_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'files_controller.freezed.dart';
part 'files_controller.g.dart';

final searchTextEditingControllerProvider = ChangeNotifierProvider.autoDispose<TextEditingController>((ref) {
  var textEditingController = TextEditingController();
  return textEditingController;
});

@riverpod
class FilePage extends _$FilePage {
  @override
  int build() {
    // Ensure that we jump back to the gcode page if the timelapse component is removed due to printer switch
    ref.listen(klipperSelectedProvider, (previous, next) {
      if (next.valueOrNull?.hasTimelapseComponent == false && state == 2) {
        state = 0;
      }
    });

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
    var baseDir = ref
        .watch(filePageProvider.select((value) => switch (value) { 1 => 'config', 2 => 'timelapse', _ => 'gcodes' }));
    return [baseDir];
  }

  update(List<String> newPath) => state = newPath;
}

@riverpod
Future<FolderContentWrapper> _fileApiResponse(_FileApiResponseRef ref, [String path = 'gcodes']) {
  return ref.watch(fileServiceSelectedProvider).fetchDirectoryInfo(path, true);
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
    folders =
        folders.where((element) => terms.every((t) => element.name.toLowerCase().contains(t))).toList(growable: false);

    files =
        files.where((element) => terms.every((t) => element.name.toLowerCase().contains(t))).toList(growable: false);
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

  JobQueueService get _jobQueueService => ref.read(jobQueueServiceSelectedProvider);

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

    var apiLoading = ref.watch(_fileApiResponseProvider(path.join('/')).select((value) => value.isLoading));

    final files = ref.watch(_procssedContentProvider);

    var jobQueueStatus = ref.watch(jobQueueSelectedProvider);

    return FilePageState(
      path: path,
      files: apiLoading ? files.toLoading() : files,
      jobQueueStatus: apiLoading ? jobQueueStatus.toLoading() : jobQueueStatus,
    );
  }

  refreshFiles() {
    ref.invalidate(_fileApiResponseProvider(state.pathAsString));
  }

  jobQueueBottomSheet() {
    ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: SheetType.jobQueueMenu));
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
      body: tr(file is Folder ? 'dialogs.delete_folder.description' : 'dialogs.delete_file.description',
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
          type: DialogType.textInput,
          title: file is Folder ? tr('dialogs.rename_folder.title') : tr('dialogs.rename_file.title'),
          confirmBtn: tr('general.rename'),
          data: TextInputDialogArguments(
              initialValue: file.fileName,
              labelText: file is Folder ? tr('dialogs.rename_folder.label') : tr('dialogs.rename_file.label'),
              suffixText: file.fileExtension,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.match('^[\\w.-]+\$', errorText: tr('pages.files.no_matches_file_pattern')),
                notContains(fileNames, errorText: tr('pages.files.file_name_in_use'))
              ]))),
    );

    if (dialogResponse?.confirmed == true) {
      String newName = dialogResponse!.data;
      if (file.fileExtension != null) newName = '$newName.${file.fileExtension!}';
      if (newName == file.name) return;
      state = state.copyWith(files: state.files.toLoading());

      try {
        await _fileService.moveFile('${state.pathAsString}/${file.name}', '${state.pathAsString}/$newName');
      } on JRpcError catch (e) {
        logger.e('Could not perform rename.', e);
        _snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          message: 'Could not rename File.\n${e.message}',
        ));
      }
    }
  }

  onAddToQueueTapped(GCodeFile file) async {
    try {
      await _jobQueueService.enqueueJob(file.pathForPrint);
    } on JRpcError catch (e) {
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        message: 'Could not add File to Queue.\n${e.message}',
      ));
    }
  }

  onCreateDirTapped() async {
    var dialogResponse = await _dialogService.show(
      DialogRequest(
          type: DialogType.textInput,
          title: tr('dialogs.create_folder.title'),
          confirmBtn: tr('general.create'),
          data: TextInputDialogArguments(
              initialValue: '',
              labelText: tr('dialogs.create_folder.label'),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.match('^[\\w.\\-]+\$', errorText: tr('pages.files.no_matches_file_pattern')),
                notContains(_usedFileNames, errorText: tr('pages.files.file_name_in_use'))
              ]))),
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
    } else if (file.isVideo) {
      _goRouter.goNamed(AppRoute.videoPlayer.name, extra: file);
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

@freezed
class FilePageState with _$FilePageState {
  const FilePageState._();

  const factory FilePageState({
    required List<String> path,
    required AsyncValue<FolderContentWrapper> files,
    required AsyncValue<JobQueueStatus> jobQueueStatus,
  }) = _FilePageState;

  bool get isInSubFolder => path.length > 1;

  String get pathAsString => path.join('/');
}
