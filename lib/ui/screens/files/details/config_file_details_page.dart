/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';

import 'package:code_text_field/code_text_field.dart';
import 'package:common/common.dart';
import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/properties.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'config_file_details_page.freezed.dart';
part 'config_file_details_page.g.dart';

final editorThemeRoot = atomOneDarkTheme['root']!;

class ConfigFileDetailPage extends HookConsumerWidget {
  const ConfigFileDetailPage({super.key, required this.machineUUID, required this.file});

  final String machineUUID;
  final GenericFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_configFilePageControllerProvider(machineUUID, file));
    final controller = ref.watch(_configFilePageControllerProvider(machineUUID, file).notifier);

    // We init it with the model. This uses the cache if its there!
    final codeController = useMemoized(() => CodeController(text: model.value?.editorContent, language: properties));
    useEffect(
      () => () {
        final text = codeController.text;
        Future(() => controller.syncEditorContent(text, force: true)).ignore();
        codeController.dispose();
      },
      [codeController],
    );
    useOnListenableChange(codeController, () {
      // Here we sync the editor content to the controller state
      controller.syncEditorContent(codeController.text);
    });

    ref.listen(_configFilePageControllerProvider(machineUUID, file), (prev, next) {
      next.whenData((model) {
        if ((prev?.isRefreshing == true || prev?.hasValue != true)) {
          talker.warning('Syncing model to codeController');
          codeController.text = model.editorContent;
        }
      });
    });

    return Scaffold(
      backgroundColor: editorThemeRoot.backgroundColor,
      appBar: AppBar(
        title: Text(file.name, overflow: TextOverflow.fade),
        actions: [
          IconButton(
            onPressed: () {
              final box = context.findRenderObject() as RenderBox?;
              final pos = box!.localToGlobal(Offset.zero) & box.size;

              SharePlus.instance
                  .share(
                    ShareParams(
                      files: [XFile(model.value!.fsFile.path, mimeType: 'text/plain', name: file.name)],
                      subject: 'Config file: ${file.name}',
                      sharePositionOrigin: pos,
                    ),
                  )
                  .ignore();
            }.only(model.hasValue),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: _ConfigFileDetailsPage(machineUUID: machineUUID, file: file, codeController: codeController),
      floatingActionButton: _Fab(machineUUID: machineUUID, file: file, codeController: codeController),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }
}

//TODO: VALIDATE ImportSettings DIAG, Exclude Objects Dialog and this! ALSO NOTE THAT PRINTER EDIT IS STILL BROKEN!!!
class _ConfigFileDetailsPage extends HookConsumerWidget {
  const _ConfigFileDetailsPage({
    super.key,
    required this.machineUUID,
    required this.file,
    required this.codeController,
  });

  final String machineUUID;
  final GenericFile file;
  final CodeController codeController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final textStyleOnError = TextStyle(color: themeData.colorScheme.onErrorContainer);

    return AsyncValueWidget(
      value: ref.watch(_configFilePageControllerProvider(machineUUID, file)),
      loading: (prog) {
        return Center(
          child: CircularProgressIndicator(value: prog?.toDouble(), color: editorThemeRoot.color),
        );
      },
      error: (e, s) => Center(
        child: ErrorCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(FlutterIcons.issue_opened_oct, color: themeData.colorScheme.onErrorContainer),
                title: Text('Error while loading file!', style: textStyleOnError),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(e.toString(), style: textStyleOnError),
              ),
            ],
          ),
        ),
      ),
      data: (model) {
        return SingleChildScrollView(
          child: Column(
            children: [
              CodeTheme(
                data: const CodeThemeData(styles: atomOneDarkTheme),
                child: CodeField(
                  textStyle: TextStyle(fontFamily: 'monospace'),
                  controller: codeController,
                  //TODO disable editing when uploading/sharing
                  // enabled: !ref.watch(configFileDetailsControllerProvider).isUploading,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

class _Fab extends ConsumerWidget {
  const _Fab({super.key, required this.machineUUID, required this.file, required this.codeController});

  final String machineUUID;
  final GenericFile file;
  final CodeController codeController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_configFilePageControllerProvider(machineUUID, file)).value;
    final controller = ref.watch(_configFilePageControllerProvider(machineUUID, file).notifier);
    final canRestart = ref.watch(
      printerProvider(
        machineUUID,
      ).select((value) => !{PrintState.paused, PrintState.printing}.contains(value.value?.print.state)),
    );

    final themeData = Theme.of(context);

    if (model == null) {
      return const SizedBox.shrink();
    }

    return SpeedDial(
      icon: FlutterIcons.save_mdi,
      activeIcon: Icons.close,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.save),
          backgroundColor: themeData.colorScheme.primaryContainer,
          foregroundColor: themeData.colorScheme.onPrimaryContainer,
          label: MaterialLocalizations.of(context).saveButtonLabel,
          onTap: () => controller.onSaveTapped(codeController.value.text),
        ),
        if (canRestart)
          SpeedDialChild(
            child: const Icon(Icons.restart_alt),
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
            label: tr('@:general.save & @:general.restart'),
            onTap: () => controller.onSaveAndRestartTapped(codeController.value.text),
          ),
      ],
      spacing: 5,
      overlayOpacity: 0.5,
      backgroundColor: model.isUploading ? themeData.disabledColor : null,
      child: model.isUploading ? const CircularProgressIndicator.adaptive() : null,
    );
  }
}

@riverpod
class _ConfigFilePageController extends _$ConfigFilePageController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  FileService get _fileService => ref.read(fileServiceProvider(machineUUID));

  KlippyService get _klippyService => ref.read(klipperServiceProvider(machineUUID));

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  Timer? _debounceSync;

  @override
  Stream<_Model> build(String machineUUID, GenericFile file) async* {
    ref.onDispose(dispose);
    // ref.keepAlive();

    final opsStream = _fileService.downloadFile(
      filePath: file.absolutPath,
      expectedFileSize: file.size,
      overWriteLocal: true,
    );
    await for (final op in opsStream) {
      if (op is FileOperationProgress && (op.progress - (state.progress ?? 0)) > 0.01) {
        state = AsyncLoading(progress: op.progress);
      } else if (op is FileDownloadComplete) {
        final content = await op.file.readAsString();
        yield _Model(editorContent: content, fsFile: op.file);
        return;
      }
    }
    throw Exception('File download stream ended without completion');
  }

  Future<void> onSaveTapped(String newContent) async {
    talker.info('Saving file ${file.name}: $newContent');
    state = state.whenData((model) => model.copyWith(isUploading: true, editorContent: newContent));
    try {
      final content = MultipartFile.fromString(newContent, filename: file.relativeToRoot);

      await _fileService.uploadFile(file.absolutPath, content).last;
      _goRouter.pop();
    } on DioException catch (e) {
      _snackBarService.show(
        SnackBarConfig(type: SnackbarType.error, title: 'Http-Error', message: 'Could not save File:.\n${e.message}'),
      );
    } finally {
      ref.invalidateSelf();
    }
  }

  Future<void> onSaveAndRestartTapped(String newContent) async {
    await onSaveTapped(newContent);
    _klippyService.restartMCUs();
  }

  void syncEditorContent(String newContent, {bool force = false}) {
    if (force) {
      state = state.whenData((model) {
        if (model.editorContent == newContent) {
          return model;
        }
        talker.info('Force synced editor content to model.');
        return model.copyWith(editorContent: newContent, hasChanges: true);
      });
      return;
    }
    _debounceSync?.cancel();
    _debounceSync = Timer(const Duration(milliseconds: 400), () {
      if (!ref.mounted) return;
      state = state.whenData((model) {
        if (model.editorContent == newContent) {
          return model;
        }
        talker.info('Synced editor content to model.');
        return model.copyWith(editorContent: newContent, hasChanges: true);
      });
    });
  }

  void dispose() {
    _debounceSync?.cancel();
  }
}

@freezed
sealed class _Model with _$Model {
  const factory _Model({
    required File fsFile,
    required String editorContent,
    @Default(false) bool isUploading,
    @Default(false) bool hasChanges,
  }) = __Model;
}
