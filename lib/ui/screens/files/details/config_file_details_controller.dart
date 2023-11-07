/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';

import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
          .downloadFile(filePath: ref.read(configFileProvider).absolutPath, overWriteLocal: true)
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

  Future<void> onSaveTapped(String code) async {
    state = state.copyWith(isUploading: true);
    try {
      await fileService.uploadAsFile(ref.read(configFileProvider).absolutPath, code);
      ref.read(goRouterProvider).pop();
    } on HttpException catch (e) {
      snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          title: 'Http-Error',
          message: 'Could not save File:.\n${e.message}'));
    } finally {
      if (mounted) {
        state = state.copyWith(isUploading: false);
      }
    }
  }

  Future<void> onSaveAndRestartTapped(String code) async {
    state = state.copyWith(isUploading: true);

    try {
      await fileService.uploadAsFile(ref.read(configFileProvider).absolutPath, code);
      klippyService.restartMCUs();
      ref.read(goRouterProvider).pop();
    } on HttpException catch (e) {
      snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          title: 'Http-Error',
          message: 'Could not save File:.\n${e.message}'));
    } finally {
      if (mounted) {
        state = state.copyWith(isUploading: false);
      }
    }
  }
}

@freezed
class ConfigDetailPageState with _$ConfigDetailPageState {
  const factory ConfigDetailPageState({
    @Default(AsyncValue.loading()) AsyncValue<String> config,
    @Default(false) bool isUploading,
  }) = _ConfigDetailPageState;
}
