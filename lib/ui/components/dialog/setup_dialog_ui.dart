import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_view.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/range_edit_form_view.dart';
import 'package:mobileraker/ui/components/dialog/exclude_object/exclude_object_dialog.dart';
import 'package:mobileraker/ui/components/dialog/import_settings/import_settings_view.dart';
import 'package:mobileraker/ui/components/dialog/renameFile/rename_file_dialog_view.dart';
import 'package:mobileraker/ui/components/dialog/stacktrace_dialog.dart';
import 'package:stacked_services/stacked_services.dart';

enum DialogType {
  numEditForm,
  rangeEditForm,
  renameFile,
  importSettings,
  excludeObject,
  stackTrace
}

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
    DialogType.excludeObject: (context, sheetRequest, completer) =>
        ExcludeObjectDialog(request: sheetRequest, completer: completer),
    DialogType.stackTrace: (context, sheetRequest, completer) =>
        StackTraceDialog(request: sheetRequest, completer: completer)
  };
  dialogService.registerCustomDialogBuilders(builders);
}
