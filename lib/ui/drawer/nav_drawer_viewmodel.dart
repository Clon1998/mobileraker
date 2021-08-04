import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/service/SelectedMachineService.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class NavDrawerViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _snackbarService = locator<SnackbarService>();
  final _selectedMachineService = locator<SelectedMachineService>();
  final String currentPath;

  NavDrawerViewModel(this.currentPath);

  String get printerDisplayName =>
      _selectedMachineService.selectedPrinter.valueOrNull?.name ?? 'No PRINTER';

  String get printerUrl =>
      _selectedMachineService.selectedPrinter.valueOrNull?.wsUrl ??
      'Please add Printer';

  navigateTo(String route) {
    _navigationService.back();
    if (currentPath != route) _navigationService.navigateTo(route);
  }

  bool isSelected(String route) => route == currentPath;

  notImpl() {
    _snackbarService.showSnackbar(message: "WIP!... Not yet implemented.");
  }
}
