import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/files/remote_file.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';

final configFileProvider =
Provider.autoDispose<RemoteFile>((ref) => throw UnimplementedError());

final configFileDetailsControllerProvider = StateNotifierProvider.autoDispose<
    ConfigFileDetailsController,
    ConfigDetailPageState>((ref) => ConfigFileDetailsController(ref));

class ConfigFileDetailsController extends StateNotifier<ConfigDetailPageState> {
  ConfigFileDetailsController(this.ref)
      : fileService = ref.watch(fileServiceSelectedProvider),
        klippyService = ref.watch(klipperServiceSelectedProvider),
        snackBarService = ref.watch(snackBarServiceProvider),
        super(

  const ConfigDetailPageState()

  ) {
  _init();
  }

  final AutoDisposeRef ref;
  final FileService fileService;
  final KlippyService klippyService;
  final SnackBarService snackBarService;

  _init() async {
    var downloadFile = await fileService
        .downloadFile(ref
        .read(configFileProvider)
        .absolutPath);
    var content = await downloadFile.readAsString();
    if (mounted) {
      state = state.copyWith(config: AsyncValue.data(content));
    }
  }

  Future<void> onSaveTapped(String code) async {
    state = state.copyWith(isUploading: true);
    try {
      await fileService.uploadAsFile(
          ref
              .read(configFileProvider)
              .absolutPath, code);
      ref.read(goRouterProvider).pop();
    } on HttpException catch (e) {
      snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          title: 'Http-Error',
          message: 'Could not save File:.\n${e.message}'
      ));
    } finally {
      if (mounted) {
        state = state.copyWith(isUploading: false);
      }
    }
  }

  Future<void> onSaveAndRestartTapped(String code) async {
    state = state.copyWith(isUploading: true);

    try {
      await fileService.uploadAsFile(
          ref
              .read(configFileProvider)
              .absolutPath, code);
      klippyService.restartMCUs();
      ref.read(goRouterProvider).pop();
    } on HttpException catch (e) {
      snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          title: 'Http-Error',
          message: 'Could not save File:.\n${e.message}'
      ));
    } finally {
      if (mounted) {
        state = state.copyWith(isUploading: false);
      }
    }
  }
}

class ConfigDetailPageState {
  const ConfigDetailPageState({
    this.config = const AsyncValue.loading(),
    this.isUploading = false,
  });

  final AsyncValue<String> config;
  final bool isUploading;

  ConfigDetailPageState copyWith({
    AsyncValue<String>? config,
    bool? isUploading,
  }) {
    return ConfigDetailPageState(
      config: config ?? this.config,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}
