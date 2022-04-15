import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class NavDrawerViewModel extends FutureViewModel<List<Machine>> {
  NavDrawerViewModel(this.currentPath);

  final String currentPath;

  final _navigationService = locator<NavigationService>();
  final _machineService = locator<MachineService>();
  final _selectedMachineService = locator<SelectedMachineService>();

  bool isManagePrintersExpanded = false;

  List<Machine> get printers {
    var list = data!;
    var selectedUUID = _selectedMachine?.uuid;

    list.sort((a, b) {
      if (a.uuid == selectedUUID) return -1; //Move selected to first position
      if (b.uuid == selectedUUID) return 1; //Move selected to first position

      return a.name.compareTo(b.name);
    });

    return list;
  }

  String get selectedPrinterDisplayName =>
      _selectedMachine?.name ?? 'NO PRINTER';

  String get printerUrl {
    if (_selectedMachine != null)
      return Uri.parse(_selectedMachine!.httpUrl).host;

    return 'Add printer first';
  }

  Machine? get _selectedMachine =>
      _selectedMachineService.selectedMachine.valueOrNull;

  @override
  Future<List<Machine>> futureToRun() => _machineService.fetchAll();

  toggleManagePrintersExpanded() {
    isManagePrintersExpanded = !isManagePrintersExpanded;
    notifyListeners();
  }

  onEditTap(Machine? machine) {
    machine ??= _selectedMachine;
    if (machine == null) {
      navigateTo(Routes.printerAdd);
    } else {
      navigateTo(Routes.printerEdit,
          arguments: PrinterEditArguments(machine: machine));
    }
  }

  onSetActiveTap(Machine machine) {
    _navigationService.back();
    _selectedMachineService.selectMachine(machine);
  }

  navigateTo(String route, {dynamic arguments}) {
    _navigationService.back();

    if (currentPath != route)
      _navigationService.navigateTo(route, arguments: arguments);
  }

  navigateMenu(String route, {dynamic arguments}) {
    _navigationService.back();

    if (currentPath != route)
      _navigationService.clearStackAndShow(route, arguments: arguments);
  }

  navigateToLegal() {
    _navigationService.navigateTo(Routes.imprintView);
  }

  bool isSelected(String route) => route == currentPath;
}
