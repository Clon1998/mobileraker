import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/enums/dialog_type.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/components/dialog/editForm/range_edit_form_view.dart';
import 'package:mobileraker/ui/views/setting/setting_viewmodel.dart';
import 'package:stacked_services/stacked_services.dart';

void showWIPSnackbar() {
  locator<SnackbarService>().showSnackbar(
      title: 'Dev-Message', message: "WIP!... Not implemented yet.");
}

String urlToWebsocketUrl(String enteredURL) {
  var parse = Uri.tryParse(enteredURL);
  if (parse == null) return enteredURL;
  if (!parse.hasScheme)
    parse = Uri.tryParse('ws://$enteredURL/websocket');
  else if (parse.isScheme('http'))
    parse = parse.replace(scheme: 'ws');
  else if (parse.isScheme('https')) parse = parse.replace(scheme: 'wss');

  return parse.toString();
}

String urlToHttpUrl(String enteredURL) {
  var parse = Uri.tryParse(enteredURL);
  if (parse == null) return enteredURL;
  if (!parse.hasScheme)
    parse = Uri.tryParse('http://$enteredURL');
  else if (parse.isScheme('ws'))
    parse = parse.replace(scheme: 'http');
  else if (parse.isScheme('wss')) parse = parse.replace(scheme: 'http');

  return parse.toString();

  // var parse = Uri.tryParse(enteredURL);
  //
  // return (parse?.hasScheme ?? false)
  //     ? enteredURL
  //     : 'ws://$enteredURL/websocket';
}

String beautifyName(String name) {
  return name.replaceAll("_", " ").capitalize!;
}

Future<DialogResponse<dynamic>?> numberOrRangeDialog(
    {required DialogService dialogService,
    required SettingService settingService,
    String? title,
    String? mainButtonTitle,
    String? secondaryButtonTitle,
    required NumberEditDialogArguments data}) {
  if (settingService.readBool(useTextInputForNumKey))
    return dialogService.showCustomDialog(
        variant: DialogType.numEditForm,
        title: title,
        mainButtonTitle: mainButtonTitle,
        secondaryButtonTitle: secondaryButtonTitle,
        data: data);
  else
    return dialogService.showCustomDialog(
        variant: DialogType.rangeEditForm,
        title: title,
        mainButtonTitle: mainButtonTitle,
        secondaryButtonTitle: secondaryButtonTitle,
        data: data);
}
