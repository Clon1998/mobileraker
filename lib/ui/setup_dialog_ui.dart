import 'package:mobileraker/app/AppSetup.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/ui/dialog/editForm/editForm_view.dart';
import 'package:stacked_services/stacked_services.dart';

enum DialogType { editForm, connectionError }

setupDialogUi() {
  final dialogService = locator<DialogService>();

  final builders = {
    DialogType.editForm: (context, sheetRequest, completer) =>
        EditFormDialogView(request: sheetRequest, completer: completer),
  };
  dialogService.registerCustomDialogBuilders(builders);
}
