/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/common.dart';
import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'config_file_details_controller.freezed.dart';
part 'config_file_details_controller.g.dart';

@Riverpod(dependencies: [])
GenericFile configFile(ConfigFileRef ref) => throw UnimplementedError();

final configFileDetailsControllerProvider =
    StateNotifierProvider.autoDispose<ConfigFileDetailsController, ConfigDetailPageState>(
        (ref) => ConfigFileDetailsController(ref));

class ConfigFileDetailsController extends StateNotifier<ConfigDetailPageState> {
  ConfigFileDetailsController(this.ref)
      : fileService = ref.watch(fileServiceSelectedProvider),
        klippyService = ref.watch(klipperServiceSelectedProvider),
        snackBarService = ref.watch(snackBarServiceProvider),
        super(const ConfigDetailPageState()) {
    _init();
  }

  final AutoDisposeRef ref;
  final FileService fileService;
  final KlippyService klippyService;
  final SnackBarService snackBarService;

  _init() async {
    try {
      var downloadFile = await fileService
          .downloadFile(
            filePath: ref.read(configFileProvider).absolutPath,
            overWriteLocal: true,
          )
          .firstWhere((element) => element is FileDownloadComplete);
      downloadFile as FileDownloadComplete;
      var content = await downloadFile.file.readAsString();
      if (mounted) {
        state = state.copyWith(config: AsyncValue.data(content));
      }
    } on MobilerakerException catch (e, s) {
      if (mounted) {
        state = state.copyWith(config: AsyncValue.error(e, s));
      }
    }
  }

  void share(BuildContext ctx) {
    state.config.whenData((config) async {
      state = state.copyWith(isSharing: true);

      try {
        final file = ref.read(configFileProvider);

        var result = await ref.read(fileServiceSelectedProvider).downloadFile(filePath: file.absolutPath).last;
        var downloadFile = result as FileDownloadComplete;

        final box = ctx.findRenderObject() as RenderBox?;
        final pos = box!.localToGlobal(Offset.zero) & box.size;

        Share.shareXFiles(
          [XFile(downloadFile.file.path, mimeType: 'text/plain', name: file.name)],
          subject: 'Config file: ${file.name}',
          sharePositionOrigin: pos,
        ).ignore();
      } catch (e) {
        ref.read(snackBarServiceProvider).show(SnackBarConfig(
              type: SnackbarType.error,
              title: 'Error while downloading file for sharing.',
              message: e.toString(),
            ));
      } finally {
        if (mounted) {
          state = state.copyWith(isSharing: false);
        }
      }
    });
  }

  Future<void> onSaveTapped(String code) async {
    state = state.copyWith(isUploading: true);
    try {
      final file = ref.read(configFileProvider);
      final content = MultipartFile.fromString(code, filename: file.relativeToRoot);

      await fileService
          .uploadFile(
            file.absolutPath,
            content,
          )
          .last;
      ref.read(goRouterProvider).pop();
    } on DioException catch (e) {
      snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: 'Http-Error',
        message: 'Could not save File:.\n${e.message}',
      ));
    } finally {
      if (mounted) {
        state = state.copyWith(isUploading: false);
      }
    }
  }

  Future<void> onSaveAndRestartTapped(String code) async {
    await onSaveTapped(code);
    klippyService.restartMCUs();
  }
}

@freezed
class ConfigDetailPageState with _$ConfigDetailPageState {
  const factory ConfigDetailPageState({
    @Default(AsyncValue.loading()) AsyncValue<String> config,
    @Default(false) bool isUploading,
    @Default(false) bool isSharing,
  }) = _ConfigDetailPageState;
}
