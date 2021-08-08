import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:stacked_services/stacked_services.dart';

void showWIPSnackbar() {
  locator<SnackbarService>().showSnackbar(title: 'Dev-Message',message: "WIP!... Not implemented yet.");
}