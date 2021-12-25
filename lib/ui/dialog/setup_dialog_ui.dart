import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/enums/dialog_type.dart';
import 'package:mobileraker/ui/dialog/editForm/num_edit_form_view.dart';
import 'package:mobileraker/ui/dialog/importSettings/import_settings_view.dart';
import 'package:stacked_services/stacked_services.dart';


setupDialogUi() {
  final dialogService = locator<DialogService>();

  final builders = {
    DialogType.numEditForm: (context, sheetRequest, completer) =>
        NumEditFormDialogView(request: sheetRequest, completer: completer),
    DialogType.numEditForm: (context, sheetRequest, completer) =>
        NumEditFormDialogView(request: sheetRequest, completer: completer),
    DialogType.importSettings: (context, sheetRequest, completer) =>
        ImportSettingsView(request: sheetRequest, completer: completer),
  };
  dialogService.registerCustomDialogBuilders(builders);
}
