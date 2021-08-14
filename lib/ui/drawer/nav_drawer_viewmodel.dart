import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/service/MachineService.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class NavDrawerViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _machineService = locator<MachineService>();
  final String currentPath;

  NavDrawerViewModel(this.currentPath);

  List<PrinterSetting> get printers {
    var iterable = _machineService.fetchAll();
    var selectedUUID = _machineService.selectedPrinter.valueOrNull?.uuid;
    List<PrinterSetting> list = List.of(iterable);
    list.sort((a, b) {
      if (a.uuid == selectedUUID) return -1; //Move selected to first position
      if (b.uuid == selectedUUID) return 1; //Move selected to first position

      return a.name.compareTo(b.name);
    });

    return list;
  }

  onEditTap(PrinterSetting? printerSetting) {
    printerSetting ??= _machineService.selectedPrinter.valueOrNull;
    if (printerSetting == null) {
      navigateTo(Routes.printersAdd);
    } else {
      navigateTo(Routes.printersEdit,
          arguments: PrintersEditArguments(printerSetting: printerSetting));
    }
  }

  onSetActiveTap(PrinterSetting printerSetting) {
    _navigationService.back();
    _machineService.setPrinterActive(printerSetting);
  }

  String get printerDisplayName =>
      _machineService.selectedPrinter.valueOrNull?.name ?? 'NO PRINTER';

  String get printerUrl {
    var printerSetting = _machineService.selectedPrinter.valueOrNull;
    if (printerSetting != null) return Uri.parse(printerSetting.wsUrl).host;

    return 'Add printer first';
  }

  navigateTo(String route, {dynamic arguments}) {
    _navigationService.back();
    if (currentPath != route)
      _navigationService.navigateTo(route, arguments: arguments);
  }

  bool isSelected(String route) => route == currentPath;
}
