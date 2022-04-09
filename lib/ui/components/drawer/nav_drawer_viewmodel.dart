import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/domain/machine.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class NavDrawerViewModel extends FutureViewModel<List<Machine>> {
  final _navigationService = locator<NavigationService>();
  final _machineService = locator<MachineService>();
  final String currentPath;

  NavDrawerViewModel(this.currentPath);


  @override
  Future<List<Machine>> futureToRun() => _machineService.fetchAll();

  List<Machine> get printers {
    var list = data!;
    var selectedUUID = _machineService.selectedMachine.valueOrNull?.uuid;

    list.sort((a, b) {
      if (a.uuid == selectedUUID) return -1; //Move selected to first position
      if (b.uuid == selectedUUID) return 1; //Move selected to first position

      return a.name.compareTo(b.name);
    });

    return list;
  }

  onEditTap(Machine? printerSetting) {
    printerSetting ??= _machineService.selectedMachine.valueOrNull;
    if (printerSetting == null) {
      navigateTo(Routes.printersAdd);
    } else {
      navigateTo(Routes.printersEdit,
          arguments: PrintersEditArguments(printerSetting: printerSetting));
    }
  }

  onSetActiveTap(Machine printerSetting) {
    _navigationService.back();
    _machineService.setMachineActive(printerSetting);
  }

  String get printerDisplayName =>
      _machineService.selectedMachine.valueOrNull?.name ?? 'NO PRINTER';

  String get printerUrl {
    var printerSetting = _machineService.selectedMachine.valueOrNull;
    if (printerSetting != null) return Uri.parse(printerSetting.httpUrl).host;

    return 'Add printer first';
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
  bool isSelected(String route) => route == currentPath;
}
