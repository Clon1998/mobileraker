import 'dart:io';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/properties.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/data/dto/files/remote_file.dart';
import 'package:mobileraker/ui/common/mixins/printer_mixin.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';
import 'package:mobileraker/ui/components/snackbar/setup_snackbar.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _FileKey = 'fileKey';

class ConfigFileDetailsViewModel extends MultipleStreamViewModel
    with SelectedMachineMixin, PrinterMixin {
  final _logger = getLogger('ConfigFileDetailsViewModel');
  final _navigationService = locator<NavigationService>();
  final _snackBarService = locator<SnackbarService>();

  final RemoteFile _file;

  bool isUploading = false;

  bool get isFileReady => dataReady(_FileKey);

  File get file => dataMap![_FileKey];

  CodeController codeController =
      CodeController(language: properties, theme: atomOneDarkTheme);

  ConfigFileDetailsViewModel(this._file);

  @override
  Map<String, StreamData> get streamsMap {
    Map<String, StreamData> parentMap = super.streamsMap;

    return {
      ...parentMap,
      if (isSelectedMachineReady)
        _FileKey: StreamData<File>(
            fileService.downloadFile(_file.absolutPath).asStream()),
    };
  }

  @override
  void onData(String key, dynamic data) async {
    super.onData(key, data);
    if (data == null) return;
    if (key == _FileKey) {
      codeController.text = await data.readAsString();
    }
  }

  Future<void> onSaveTapped() async {
    isUploading = true;
    notifyListeners();
    try {
      _navigationService.back();
      await fileService.uploadAsFile(_file.absolutPath, codeController.text);
    } on HttpException catch (e) {
      isUploading = false;
      notifyListeners();
      _snackBarService.showCustomSnackBar(
          variant: SnackbarType.error,
          duration: const Duration(seconds: 5),
          title: 'Error',
          message: 'Could not save File:.\n${e.message}');
    }
  }

  Future<void> onSaveAndRestartTapped() async {
    isUploading = true;
    notifyListeners();
    try {
      _navigationService.back();
      await fileService.uploadAsFile(_file.absolutPath, codeController.text);
      klippyService.restartMCUs();
    } on HttpException catch (e) {
      isUploading = false;
      notifyListeners();
      _snackBarService.showCustomSnackBar(
          variant: SnackbarType.error,
          duration: const Duration(seconds: 5),
          title: 'Error',
          message: 'Could not save File:.\n${e.message}');
    }
  }
}
