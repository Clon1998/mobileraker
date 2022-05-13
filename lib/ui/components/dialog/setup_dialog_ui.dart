import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/ui/components/dialog/editForm/num_edit_form_view.dart';
import 'package:mobileraker/ui/components/dialog/editForm/range_edit_form_view.dart';
import 'package:mobileraker/ui/components/dialog/importSettings/import_settings_view.dart';
import 'package:mobileraker/ui/components/dialog/renameFile/rename_file_dialog_view.dart';
import 'package:stacked_services/stacked_services.dart';

enum DialogType { numEditForm, rangeEditForm, renameFile, importSettings }

setupDialogUi() {
  final dialogService = locator<DialogService>();

  final builders = {
    DialogType.numEditForm: (context, sheetRequest, completer) =>
        NumEditFormDialogView(request: sheetRequest, completer: completer),
    DialogType.rangeEditForm: (context, sheetRequest, completer) =>
        RangeEditFormDialogView(request: sheetRequest, completer: completer),
    DialogType.importSettings: (context, sheetRequest, completer) =>
        ImportSettingsView(request: sheetRequest, completer: completer),
    DialogType.renameFile: (context, sheetRequest, completer) =>
        RenameFileDialogView(request: sheetRequest, completer: completer),
  };
  dialogService.registerCustomDialogBuilders(builders);
}
