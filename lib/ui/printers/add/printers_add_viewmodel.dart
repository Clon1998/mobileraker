import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/service/PrinterSettingsService.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class PrintersAddViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _snackbarService = locator<SnackbarService>();
  final _printerSettingService = locator<PrinterSettingsService>();
  final _fbKey = GlobalKey<FormBuilderState>();

  Key get formKey => _fbKey;
  var printers = Hive.box<PrinterSetting>('printers');

  onFormConfirm() {
    if (_fbKey.currentState!.saveAndValidate()) {
      var printerName = _fbKey.currentState!.value['printerName'];
      var printerUrl = _fbKey.currentState!.value['printerUrl'];
      var printerSetting = PrinterSetting(printerName, printerUrl);
      _printerSettingService
          .addPrinter(printerSetting)
          .then((value) =>
          _navigationService.popUntil((route) {
            return route.settings.name == Routes.printers;
          }
          )
      );
    }
  }

  onTestConnectionTap() {
    _snackbarService.showSnackbar(message: "WIP!... Not yet implemented.");
  }
}
