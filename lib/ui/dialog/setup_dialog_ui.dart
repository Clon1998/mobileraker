import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/enums/dialog_type.dart';
import 'package:mobileraker/ui/dialog/editForm/editForm_view.dart';
import 'package:stacked_services/stacked_services.dart';


setupDialogUi() {
  final dialogService = locator<DialogService>();

  final builders = {
    DialogType.editForm: (context, sheetRequest, completer) =>
        EditFormDialogView(request: sheetRequest, completer: completer),
  };
  dialogService.registerCustomDialogBuilders(builders);
}
