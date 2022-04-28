import 'dart:io';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/atelier-cave-dark.dart';
import 'package:flutter_highlight/themes/atelier-lakeside-dark.dart';
import 'package:flutter_highlight/themes/atelier-plateau-dark.dart';
import 'package:flutter_highlight/themes/atelier-seaside-dark.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/dark.dart';
import 'package:highlight/languages/properties.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/dto/files/remote_file.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/ui/components/snackbar/setup_snackbar.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ConfigFileDetailsViewModel extends FutureViewModel<File> {
  ConfigFileDetailsViewModel(this._file);

  final _logger = getLogger('ConfigFileDetailsViewModel');
  final _navigationService = locator<NavigationService>();
  final _snackBarService = locator<SnackbarService>();
  final _selectedMachineService = locator<SelectedMachineService>();

  final RemoteFile _file;

  bool isUploading = false;

  Machine? get _machine => _selectedMachineService.selectedMachine.valueOrNull;

  FileService? get _fileService => _machine?.fileService;

  KlippyService? get _klippyService => _machine?.klippyService;

  CodeController codeController =
      CodeController(language: properties, theme: atomOneDarkTheme);

  @override
  Future<File> futureToRun() => _fileService!.downloadFile(_file.absolutPath);

  @override
  void onData(File? data) async {
    super.onData(data);
    if (data == null) return;
    codeController.text = await data.readAsString();
  }

  Future<void> onSaveTapped() async {
    isUploading = true;
    notifyListeners();
    try {
      _navigationService.back();
      await _fileService!.uploadAsFile(_file.absolutPath, codeController.text);
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
      await _fileService!.uploadAsFile(_file.absolutPath, codeController.text);
      _klippyService!.restartMCUs();
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
