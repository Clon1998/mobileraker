/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/common.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/moonraker/file_item.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/enums/file_action_sheet_action_enum.dart';
import 'package:common/data/enums/gcode_file_action_sheet_action_enum.dart';
import 'package:common/data/model/file_interaction_menu_event.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/job_queue/service/job_queue_service.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../routing/app_router.dart';
import '../../ui/components/bottomsheet/action_bottom_sheet.dart';
import '../../ui/components/dialog/text_input/text_input_dialog.dart';
import '../../ui/screens/files/components/remote_file_icon.dart';
import 'bottom_sheet_service_impl.dart';
import 'dialog_service_impl.dart';

part 'file_interaction_service.g.dart';

final _zipDateFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');

@riverpod
FileInteractionService fileInteractionService(Ref ref, String machineUUID) {
  return FileInteractionService(
    machineUUID,
    ref.watch(bottomSheetServiceProvider),
    ref.watch(dialogServiceProvider),
    ref.watch(snackBarServiceProvider),
    ref.watch(fileServiceProvider(machineUUID)),
    ref.watch(jobQueueServiceProvider(machineUUID)),
    ref.watch(printerServiceProvider(machineUUID)),
    ref.watch(klipperServiceProvider(machineUUID)),
    ref.watch(goRouterProvider),
    ref.watch(isSupporterProvider),
  );
}

class FileInteractionService {
  final String _machineUUID;
  final BottomSheetService _bottomSheetService;
  final DialogService _dialogService;
  final SnackBarService _snackBarService;
  final FileService _fileService;
  final JobQueueService _jobQueueService;
  final PrinterService _printerService;
  final KlippyService _klippyService;
  final GoRouter _goRouter;

  final bool _isSupporter;

  const FileInteractionService(
    this._machineUUID,
    this._bottomSheetService,
    this._dialogService,
    this._snackBarService,
    this._fileService,
    this._jobQueueService,
    this._printerService,
    this._klippyService,
    this._goRouter,
    this._isSupporter,
  );

  Stream<FileInteractionMenuEvent> showFileActionMenu(
    RemoteFile file,
    Rect origin,
    String machineUUID, [
    List<String>? usedNames,
  ]) async* {
    final canStartPrint = _printerService.current.print.state != PrintState.printing &&
        _printerService.current.print.state != PrintState.paused;
    final klippyReady = _klippyService.klippyCanReceiveCommands;

    final arg = ActionBottomSheetArgs(
      title: Tooltip(message: file.name, child: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      subtitle: file.fileExtension?.let((ext) => Text(ext.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis)),
      leading: SizedBox.square(
        dimension: 33,
        child: RemoteFileIcon(
          machineUUID: machineUUID,
          file: file,
          alignment: Alignment.centerLeft,
          imageBuilder: (BuildContext context, ImageProvider imageProvider) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(7)),
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
            );
          },
        ),
      ),
      actions: _getFileActions(file, canStartPrint, klippyReady),
    );

    logger.i('[FileInteractionService($_machineUUID)] showing file action menu for ${file.name}');

    final resp =
        await _bottomSheetService.show(BottomSheetConfig(type: SheetType.actions, isScrollControlled: true, data: arg));

    logger.i('[FileInteractionService($_machineUUID)] file action menu response: $resp');
    if (!resp.confirmed) return;

    yield FileActionSelected(action: resp.data, files: [file]);
    await Future.delayed(kThemeAnimationDuration);
    yield* _handleFileAction(resp.data, file, origin, machineUUID, usedNames);
  }

  Stream<FileInteractionMenuEvent> showMultiFileActionMenu(
      List<RemoteFile> files, Rect origin, String machineUUID) async* {
    final gcodeFiles = files.whereType<GCodeFile>().toList();

    final arg = ActionBottomSheetArgs(
      title: Text(
        '${files.length} ${plural('pages.files.element', files.length)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (gcodeFiles.isNotEmpty) ...[
          GcodeFileSheetAction.addToQueue,
          DividerSheetAction.divider,
        ],
        FileSheetAction.zipFile,
        FileSheetAction.download,
        DividerSheetAction.divider,
        FileSheetAction.move,
        FileSheetAction.delete,
      ],
    );

    logger.i('[FileInteractionService($_machineUUID)] showing multi file action menu for ${files.length} files');

    final resp =
        await _bottomSheetService.show(BottomSheetConfig(type: SheetType.actions, isScrollControlled: true, data: arg));

    logger.i('[FileInteractionService($_machineUUID)] multi file action menu response: $resp');
    if (!resp.confirmed) return;

    yield FileActionSelected(action: resp.data, files: files);
    await Future.delayed(kThemeAnimationDuration);
    yield* _handleMutliFileAction(resp.data, files, gcodeFiles, origin, machineUUID);
  }

  Stream<FileInteractionMenuEvent> showNewFileOptionsMenu(
    String parentPath,
    Rect origin,
    String machineUUID, [
    List<String> allowedTypes = const [],
    List<String>? usedNames,
  ]) async* {
    const args = ActionBottomSheetArgs(actions: [
      FileSheetAction.newFolder,
      FileSheetAction.newFile,
      DividerSheetAction.divider,
      FileSheetAction.uploadFile,
      FileSheetAction.uploadFiles,
    ]);

    final resp = await _bottomSheetService
        .show(BottomSheetConfig(type: SheetType.actions, isScrollControlled: true, data: args));

    if (!resp.confirmed) return;

    yield FileActionSelected(action: resp.data, files: []);
    await Future.delayed(kThemeAnimationDuration);
    yield* _handleNewFileAction(resp.data, parentPath, origin, machineUUID, allowedTypes, usedNames);
  }

  //////////////////// ACTIONS ////////////////////

  Stream<FileInteractionMenuEvent> deleteFilesAction(List<RemoteFile> files) async* {
    if (files.isEmpty) return;
    String body;
    if (files.length == 1) {
      final file = files.first;
      body = tr(
        file is Folder ? 'dialogs.delete_folder.description' : 'dialogs.delete_file.description',
        args: [file.name],
      );
    } else {
      body = tr('dialogs.delete_files.description', args: [files.length.toString()]);
    }

    var dialogResponse = await _dialogService.showDangerConfirm(
      title: tr('dialogs.delete_folder.title'),
      body: body,
      actionLabel: tr('general.delete'),
    );

    if (dialogResponse?.confirmed == true) {
      // state = FilePageState.loading(state.path);

      yield FileOperationTriggered(action: FileSheetAction.delete, files: files);

      delete(RemoteFile file) async {
        try {
          if (file is Folder) {
            await _fileService.deleteDirForced(file.absolutPath);
          } else {
            await _fileService.deleteFile(file.absolutPath);
          }
        } on JRpcError catch (e) {
          _snackBarService.show(SnackBarConfig(
            type: SnackbarType.error,
            message: 'Could not delete ${file.name}.\n${e.message}',
          ));
        }
      }

      for (var file in files) {
        delete(file);
      }
    }
  }

  Stream<FileInteractionMenuEvent> renameFileAction(RemoteFile file, List<String>? usedNames) async* {
    usedNames ??= await _fileService.fetchDirectoryInfo(file.parentPath).then((e) => e.folderFileNames);
    usedNames!.remove(file.name);

    var dialogResponse = await _dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        title: file is Folder ? tr('dialogs.rename_folder.title') : tr('dialogs.rename_file.title'),
        actionLabel: tr('general.rename'),
        data: TextInputDialogArguments(
          initialValue: file.fileName,
          labelText: file is Folder ? tr('dialogs.rename_folder.label') : tr('dialogs.rename_file.label'),
          suffixText: file.fileExtension?.let((it) => '.$it'),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.match(
              RegExp(r'^\w?[\w .-]*[\w-]$'),
              errorText: tr('pages.files.no_matches_file_pattern'),
            ),
            notContains(
              usedNames,
              errorText: tr('form_validators.file_name_in_use'),
            ),
          ]),
        ),
      ),
    );

    if (dialogResponse?.confirmed == true) {
      String newName = dialogResponse!.data;
      if (file.fileExtension != null) newName = '$newName.${file.fileExtension!}';
      if (newName == file.name) return;

      try {
        yield FileOperationTriggered(action: FileSheetAction.rename, files: [file]);
        await _fileService.moveFile(
          file.absolutPath,
          '${file.parentPath}/$newName',
        );
      } on JRpcError catch (e) {
        logger.e('Could not perform rename.', e);
        _snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          message: 'Could not rename File.\n${e.message}',
        ));
      }
    }
  }

  Stream<FileInteractionMenuEvent> moveFilesAction(List<RemoteFile> files) async* {
    if (files.isEmpty) return;
    // await _printerService.startPrintFile(file);
    var first = files.first;
    final res = await _goRouter.pushNamed(
      AppRoute.fileManager_exlorer_move.name,
      pathParameters: {'path': first.parentPath.split('/').first},
      queryParameters: {'machineUUID': _machineUUID, 'submitLabel': tr('pages.files.move_here')},
    );

    if (res case String()) {
      if (first.parentPath == res) return;
      final newPath = res;
      logger.i('[FileInteractionService($_machineUUID)] moving files to $res');

      final waitFor = <Future>[];
      for (var file in files) {
        final f = _fileService.moveFile(file.absolutPath, '$newPath/${file.name}');
        waitFor.add(f);
      }
      try {
        await Future.wait(waitFor);
        _snackBarService.show(SnackBarConfig(
          type: SnackbarType.info,
          title: tr('pages.files.file_operation.move_success.title'),
          message: tr('pages.files.file_operation.move_success.body', args: [newPath]),
        ));
      } catch (e, s) {
        _onOperationError(e, s, 'move');
      }
    }
  }

  Stream<FileInteractionMenuEvent> copyFileAction(RemoteFile file) async* {
    // First name of the new copy
    var dialogResponse = await _dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        title: file is Folder ? tr('dialogs.copy_folder.title') : tr('dialogs.copy_file.title'),
        actionLabel: tr('pages.files.file_actions.copy'),
        data: TextInputDialogArguments(
          initialValue: '${file.fileName}_copy${file.fileExtension?.let((it) => '.$it') ?? ''}',
          labelText: file is Folder ? tr('dialogs.copy_file.label') : tr('dialogs.copy_file.label'),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.match(
              RegExp(r'^\w?[\w .-]*[\w-]$'),
              errorText: tr('pages.files.no_matches_file_pattern'),
            ),
          ]),
        ),
      ),
    );

    if (dialogResponse?.confirmed == false) return;
    final copyName = dialogResponse!.data;

    final res = await _goRouter.pushNamed(
      AppRoute.fileManager_exlorer_move.name,
      pathParameters: {'path': file.parentPath.split('/').first},
      queryParameters: {'machineUUID': _machineUUID, 'submitLabel': tr('pages.files.copy_here')},
    );

    if (res case String()) {
      //TODO: Verify toLoading:true is not required...
      // state = state.copyWith(folderContent: state.folderContent.toLoading(true));
      yield FileOperationTriggered(action: FileSheetAction.copy, files: [file]);

      final copyPath = '$res/$copyName';
      logger.i('[FileInteractionService($_machineUUID)] creating copy of file ${file.name} at $copyPath');
      await _fileService.copyFile(file.absolutPath, copyPath);
      _snackBarService.show(SnackBarConfig(
        title: tr('pages.files.file_operation.copy_created.title'),
        message: tr('pages.files.file_operation.copy_created.body', args: [copyPath]),
      ));
    }
  }

  Stream<FileInteractionMenuEvent> previewGCodeAction(GCodeFile file) async* {
    _goRouter.pushNamed(
      ProRoutes.fileManager_exlorer_gcodePreview.name,
      pathParameters: {'path': file.parentPath},
      queryParameters: {'machineUUID': _machineUUID},
      extra: file,
    );
  }

  Stream<FileInteractionMenuEvent> addFilesToQueueAction(List<GCodeFile> files) async* {
    if (!_isSupporter) {
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.warning,
        title: tr('components.supporter_only_feature.dialog_title'),
        message: tr('components.supporter_only_feature.job_queue'),
        duration: const Duration(seconds: 5),
      ));
      return;
    }
    if (files.isEmpty) return;

    try {
      final futures = files.map((e) => _jobQueueService.enqueueJob(e.pathForPrint));
      await Future.wait(futures);
    } on JRpcError catch (e) {
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        message: 'Could not add Files to Queue.\n${e.message}',
      ));
    }
  }

  Stream<FileInteractionMenuEvent> preheatAction(GCodeFile file) async* {
    final tempArgs = [
      '170',
      file.firstLayerTempBed?.toStringAsFixed(0) ?? '60',
    ];
    final resp = await _dialogService.showConfirm(
      title: 'pages.files.details.preheat_dialog.title'.tr(),
      body: tr('pages.files.details.preheat_dialog.body', args: tempArgs),
      actionLabel: 'pages.files.details.preheat'.tr(),
    );
    if (resp?.confirmed != true) return;
    _printerService.setHeaterTemperature('extruder', 170);

    if (_printerService.currentOrNull?.heaterBed != null) {
      _printerService.setHeaterTemperature(
        'heater_bed',
        (file.firstLayerTempBed ?? 60.0).toInt(),
      );
    }
    _snackBarService.show(SnackBarConfig(
      title: tr('pages.files.details.preheat_snackbar.title'),
      message: tr(
        'pages.files.details.preheat_snackbar.body',
        args: tempArgs,
      ),
    ));
  }

  Stream<FileInteractionMenuEvent> submitJobAction(GCodeFile file) async* {
    await _printerService.startPrintFile(file);
    _goRouter.goNamed(AppRoute.dashBoard.name);
  }

  Stream<FileInteractionMenuEvent> downloadFileAction(List<RemoteFile> files, Rect origin) async* {
    if (!_isSupporter) {
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.warning,
        title: tr('components.supporter_only_feature.dialog_title'),
        message: tr('components.supporter_only_feature.full_file_management'),
        duration: const Duration(seconds: 5),
      ));
      return;
    }
    if (files.isEmpty) return;

    try {
      final zipName = '${_zipDateFormat.format(DateTime.now())}.zip';
      String fileToDownload;
      int? fileToDownloadSize;
      String subject;
      String mimeType;
      if (files.length == 1) {
        final file = files.first;
        if (file case Folder()) {
          final zipPath = '${file.absolutPath}-$zipName.zip';
          yield FileOperationTriggered(action: FileSheetAction.download, files: files);

          final res = await _handleZipOperation(zipPath, [file.absolutPath], false);
          if (res == null) return;
          fileToDownload = res.fullPath;
          fileToDownloadSize = res.size;
          mimeType = 'application/zip';
          subject = '${file.name}-$zipName.zip';
        } else {
          fileToDownload = file.absolutPath;
          fileToDownloadSize = file.size;
          mimeType = switch (file.fileExtension) {
            'png' => 'image/png',
            'gif' => 'image/gif',
            'jpg' || 'jpeg' => 'image/jpeg',
            'mp4' => 'video/mp4',
            _ => 'text/plain',
          };
          subject = file.name;
        }
      } else {
        final zipPath = '${files.first.parentPath}/$zipName';
        yield FileOperationTriggered(action: FileSheetAction.download, files: files);

        final res = await _handleZipOperation(zipPath, files.map((e) => e.absolutPath).toList(), false);
        if (res == null) return;
        fileToDownload = res.fullPath;
        fileToDownloadSize = res.size;
        mimeType = 'application/zip';
        subject = zipName;
      }

      final token = CancelToken();

      final downloadStream = _fileService
          .downloadFile(filePath: fileToDownload, expectedFileSize: fileToDownloadSize, cancelToken: token)
          .distinct((a, b) {
        // If both are Download Progress, only update in 0.01 steps:
        const epsilon = 0.01;
        if (a is FileOperationProgress && b is FileOperationProgress) {
          return (b.progress - a.progress) < epsilon;
        }

        return a == b;
      });

      FileTransferOperationProgress? last;
      await for (var download in downloadStream) {
        last = FileTransferOperationProgress(
          action: FileSheetAction.download,
          files: files,
          event: download,
          token: token,
        );
        yield last;
      }

      if (last?.event is FileOperationCanceled) {
        _onOperationCanceled(false);
        return;
      }

      final downloadedFilePath = (last?.event as FileDownloadComplete).file.path;

      try {
        await Share.shareXFiles(
          [XFile(downloadedFilePath, mimeType: mimeType)],
          subject: subject,
          sharePositionOrigin: origin,
        );
      } catch (e) {
        logger.e('Could not share file', e);
      }
    } catch (e, s) {
      logger.e('[FileInteractionService($_machineUUID)] Could not download file.', e, s);
      _onOperationError(e, s, 'download');
    }
  }

  Stream<FileInteractionMenuEvent> zipFilesAction(List<RemoteFile> toZip) async* {
    logger.i('[FileInteractionService($_machineUUID)] creating new archive for files');

    final initialName = toZip.length == 1 ? toZip.first.name : _zipDateFormat.format(DateTime.now());

    final res = await _dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        title: tr('dialogs.create_archive.title'),
        actionLabel: tr('general.create'),
        data: TextInputDialogArguments(
          initialValue: initialName,
          labelText: tr('dialogs.create_archive.label'),
          suffixText: '.zip',
          valueTransformer: (value) => value?.let((it) => '$it.zip'),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.match(
              RegExp(r'^\w?[\w .-]*[\w-]$'),
              errorText: tr('pages.files.no_matches_file_pattern'),
            ),
          ]),
        ),
      ),
    );

    if (res?.confirmed != true) return;
    yield FileOperationTriggered(action: FileSheetAction.zipFile, files: toZip);

    final archiveDest = '${toZip.first.parentPath}/${res!.data as String}';
    await _handleZipOperation(archiveDest, toZip.map((e) => e.absolutPath).toList());
  }

  Stream<FileInteractionMenuEvent> createEmptyFolderAction(String parentPath, List<String>? usedNames) async* {
    usedNames ??= await _fileService.fetchDirectoryInfo(parentPath).then((e) => e.folderFileNames);

    logger.i('[FileInteractionService($_machineUUID)] creating new folder');

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
              RegExp(r'^\w?[\w .-]*[\w-]$'),
              errorText: tr('pages.files.no_matches_file_pattern'),
            ),
            notContains(
              usedNames!,
              errorText: tr('form_validators.file_name_in_use'),
            ),
          ]),
        ),
      ),
    );

    if (dialogResponse?.confirmed == true) {
      yield const FileOperationTriggered(action: FileSheetAction.newFolder, files: []);

      String newName = dialogResponse!.data;
      _fileService.createDir('$parentPath/$newName').ignore();
    }
  }

  Stream<FileInteractionMenuEvent> uploadFileAction(String parentPath, List<String> allowedFileTypes,
      [bool multiple = false]) async* {
    if (!_isSupporter) {
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.warning,
        title: tr('components.supporter_only_feature.dialog_title'),
        message: tr('components.supporter_only_feature.full_file_management'),
        duration: const Duration(seconds: 5),
      ));
      return;
    }

    logger.i('[FileInteractionService($_machineUUID)] uploading file. Allowed: $allowedFileTypes');

    bool useAny = kDebugMode || Platform.isAndroid;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: useAny ? FileType.any : FileType.custom,
      allowedExtensions: allowedFileTypes.unless(useAny),
      withReadStream: true,
      allowMultiple: multiple,
      withData: false,
    );

    logger.i('[FileInteractionService($_machineUUID)] FilePicker result: $result');
    if (result == null || result.count == 0) return;

    // If we did not filter by OS, we need to check the file extension manually here

    if (useAny) {
      final invalidFiles = result.files.where((e) => !allowedFileTypes.contains(e.extension));
      if (invalidFiles.isNotEmpty) {
        _snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          title: tr('pages.files.file_operation.upload_failed.reasons.type_mismatch.title'),
          message: tr('pages.files.file_operation.upload_failed.reasons.type_mismatch.body',
              args: [allowedFileTypes.map((e) => '.$e').join(', ')]),
        ));
        yield const FileActionFailed(action: FileSheetAction.uploadFile, files: [], error: 'Invalid file type');
        return;
      }
    }

    for (var toUpload in result.files) {
      logger.i('[FileInteractionService($_machineUUID)] Selected file: ${toUpload.name}');

      final relativeToRoot = parentPath.split('/').skip(1).join('/');

      final mPrt = MultipartFile.fromStream(
        () => toUpload.readStream!,
        toUpload.size,
        filename: '$relativeToRoot/${toUpload.name}',
      );
      yield* _handleFileUpload(parentPath, mPrt);
    }
  }

  Stream<FileInteractionMenuEvent> newFileAction(String parentPath, List<String>? usedNames) async* {
    logger.i('[FileInteractionService($_machineUUID)] creating new file');

    usedNames ??= await _fileService.fetchDirectoryInfo(parentPath).then((e) => e.folderFileNames);

    // final allowedExtensions = _root == 'gcodes' ? [...gcodeFileExtensions] : [...configFileExtensions, ...textFileExtensions];

    final res = await _dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        title: tr('dialogs.create_file.title'),
        actionLabel: tr('general.create'),
        data: TextInputDialogArguments(
          initialValue: '',
          labelText: tr('dialogs.create_file.label'),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.match(
              RegExp(r'^\w?[\w .-]*[\w-]$'),
              errorText: tr('pages.files.no_matches_file_pattern'),
            ),
            notContains(
              usedNames!,
              errorText: tr('form_validators.file_name_in_use'),
            ),
          ]),
        ),
      ),
    );

    if (res?.confirmed != true) return;
    final fileName = res!.data;
    final relativeToRoot = parentPath.split('/').skip(1).join('/');
    final multipartFile = MultipartFile.fromString('', filename: '$relativeToRoot/$fileName');

    yield* _handleFileUpload(parentPath, multipartFile);
  }

  //////////////////// END ACTIONS ////////////////////

  //////////////////// MISC ////////////////////

  List<BottomSheetAction> _getFileActions(RemoteFile file, bool canStartPrint, bool klippyReady) {
    final actions = <BottomSheetAction>[];

    if (file is GCodeFile) {
      actions.addAll([
        GcodeFileSheetAction.submitPrintJob.let((t) => canStartPrint && klippyReady ? t : t.disable),
        GcodeFileSheetAction.preheat
            .let((t) => file.firstLayerTempBed != null && canStartPrint && klippyReady ? t : t.disable),
        GcodeFileSheetAction.preview,
        GcodeFileSheetAction.addToQueue,
        DividerSheetAction.divider,
      ]);
    }

    actions.addAll([
      FileSheetAction.zipFile,
      FileSheetAction.download,
      DividerSheetAction.divider,
      FileSheetAction.rename,
      FileSheetAction.copy,
      FileSheetAction.move,
      FileSheetAction.delete,
    ]);

    return actions;
  }

  Stream<FileInteractionMenuEvent> _handleFileAction(
    BottomSheetAction action,
    RemoteFile file,
    Rect origin,
    String machineUUID,
    List<String>? usedNames,
  ) async* {
    try {
      switch (action) {
        case FileSheetAction.delete:
          yield* deleteFilesAction([file]);
          break;
        case FileSheetAction.rename:
          yield* renameFileAction(file, usedNames);
          break;
        case GcodeFileSheetAction.preview when file is GCodeFile:
          yield* previewGCodeAction(file);
          break;
        case GcodeFileSheetAction.addToQueue when file is GCodeFile:
          yield* addFilesToQueueAction([file]);
          break;
        case GcodeFileSheetAction.preheat when file is GCodeFile:
          yield* preheatAction(file);
          break;
        case GcodeFileSheetAction.submitPrintJob when file is GCodeFile:
          yield* submitJobAction(file);
          break;
        case FileSheetAction.download:
          yield* downloadFileAction([file], origin);
          break;
        case FileSheetAction.move:
          yield* moveFilesAction([file]);
          break;
        case FileSheetAction.copy:
          yield* copyFileAction(file);
          break;
        case FileSheetAction.zipFile:
          yield* zipFilesAction([file]);
          break;
        default:
          logger.w('Action not implemented: $action');
          yield FileActionFailed(action: action, files: [file], error: 'Action not implemented');
      }
      yield FileOperationCompleted(action: action, files: [file]);
    } catch (e) {
      yield FileActionFailed(action: action, files: [file], error: e.toString());
    }
  }

  Stream<FileInteractionMenuEvent> _handleMutliFileAction(
    BottomSheetAction action,
    List<RemoteFile> files,
    List<GCodeFile> gcodeFiles,
    Rect origin,
    String machineUUID,
  ) async* {
    try {
      switch (action) {
        case FileSheetAction.delete:
          yield* deleteFilesAction(files);
          break;
        case FileSheetAction.move:
          yield* moveFilesAction(files);
          break;
        case FileSheetAction.zipFile:
          yield* zipFilesAction(files);
          break;
        case FileSheetAction.download:
          yield* downloadFileAction(files, origin);
          break;
        case GcodeFileSheetAction.addToQueue:
          yield* addFilesToQueueAction(gcodeFiles);
          break;
      }
      yield FileOperationCompleted(action: action, files: files);
    } catch (e) {
      yield FileActionFailed(action: action, files: files, error: e.toString());
    }
  }

  Stream<FileInteractionMenuEvent> _handleNewFileAction(
    BottomSheetAction action,
    String parentPath,
    Rect origin,
    String machineUUID,
    List<String> allowedTypes,
    List<String>? usedNames,
  ) async* {
    try {
      switch (action) {
        case FileSheetAction.newFolder:
          yield* createEmptyFolderAction(parentPath, usedNames);
          break;
        case FileSheetAction.uploadFiles:
        case FileSheetAction.uploadFile:
          yield* uploadFileAction(parentPath, allowedTypes, action == FileSheetAction.uploadFiles);
          break;
        case FileSheetAction.newFile:
          yield* newFileAction(parentPath, usedNames ?? []);
          break;
      }
      yield FileOperationCompleted(action: action, files: []);
    } catch (e) {
      yield FileActionFailed(action: action, files: [], error: e.toString());
    }
  }

  Future<FileItem?> _handleZipOperation(String dest, List<String> targets, [bool showSnack = true]) async {
    try {
      final zipFile = await _fileService.zipFiles(dest, targets);

      logger.i('[FileInteractionService($_machineUUID)] Files zipped');

      if (showSnack) {
        _snackBarService.show(SnackBarConfig(
          type: SnackbarType.info,
          title: tr('pages.files.file_operation.zipping_success.title'),
          message: tr('pages.files.file_operation.zipping_success.body'),
        ));
      }
      return zipFile;
    } catch (e, s) {
      logger.e('[FileInteractionService($_machineUUID)] Could not zip files.', e, s);
      _onOperationError(e, s, 'zipping');
    }
    return null;
  }

  Stream<FileInteractionMenuEvent> _handleFileUpload(String parentPath, MultipartFile toUpload) async* {
    try {
      final token = CancelToken();
      final uploadStream = _fileService.uploadFile(parentPath, toUpload, token);

      FileTransferOperationProgress? last;
      await for (var update in uploadStream) {
        last =
            FileTransferOperationProgress(action: FileSheetAction.uploadFile, files: [], event: update, token: token);
        yield last;
      }

      if (last?.event is FileOperationCanceled) {
        _onOperationCanceled(true);
        return;
      }

      logger.i('[FileInteractionService($_machineUUID)] File uploaded');

      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.files.file_operation.upload_success.title'),
        message: tr('pages.files.file_operation.upload_success.body'),
      ));
    } catch (e, s) {
      logger.e('[FileInteractionService($_machineUUID)] Could not upload file.', e, s);
      _onOperationError(e, s, 'upload');
      yield const FileActionFailed(action: FileSheetAction.uploadFile, files: [], error: 'Upload failed');
    }
  }

  //////////////////// END MISC ////////////////////

  //////////////////// UI-Notificaiton ////////////////////

  void _onOperationCanceled(bool isUpload) {
    final prefix = isUpload ? 'upload' : 'download';
    _snackBarService.show(SnackBarConfig(
      type: SnackbarType.warning,
      title: tr('pages.files.file_operation.${prefix}_canceled.title'),
      message: tr('pages.files.file_operation.${prefix}_canceled.body'),
    ));
  }

  void _onOperationError(Object error, StackTrace stack, String operation) {
    _snackBarService.show(SnackBarConfig.stacktraceDialog(
      dialogService: _dialogService,
      snackTitle: tr('pages.files.file_operation.${operation}_failed.title'),
      snackMessage: tr('pages.files.file_operation.${operation}_failed.body'),
      exception: error,
      stack: stack,
    ));
  }

//////////////////// END UI-Notificaiton ////////////////////
}
