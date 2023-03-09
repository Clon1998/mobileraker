import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';

final navDrawerControllerProvider =
    StateNotifierProvider.autoDispose<NavDrawerController, bool>(
        (ref) => NavDrawerController(ref));

class NavDrawerController extends StateNotifier<bool> {
  NavDrawerController(this.ref) : super(false);
  final Ref ref;
  toggleManagePrintersExpanded() {
    state = !state;
  }

  navigateTo(String route, {dynamic arguments}) {
    var goRouter = ref.read(goRouterProvider);
    goRouter.pop();
    goRouter.go(route, extra: arguments);
  }

  pushingTo(String route, {dynamic arguments}) {
    var goRouter = ref.read(goRouterProvider);
    goRouter.pop();
    goRouter.push(route, extra: arguments);
  }
}

//
// class NavDrawerViewModel extends FutureViewModel<List<Machine>> {
//   NavDrawerViewModel(this.currentPath);
//
//   final String currentPath;
//
//   final _navigationService = locator<NavigationService>();
//   final _machineService = locator<MachineService>();
//   final _selectedMachineService = locator<SelectedMachineService>();
//
//   bool isManagePrintersExpanded = false;
//
//   List<Machine> get printers {
//     var list = data!;
//     var selectedUUID = _selectedMachine?.uuid;
//
//     list.sort((a, b) {
//       if (a.uuid == selectedUUID) return -1; //Move selected to first position
//       if (b.uuid == selectedUUID) return 1; //Move selected to first position
//
//       return a.name.compareTo(b.name);
//     });
//
//     return list;
//   }
//
//   String get selectedPrinterDisplayName =>
//       _selectedMachine?.name ?? 'NO PRINTER';
//
//   String get printerUrl {
//     if (_selectedMachine != null)
//       return Uri.parse(_selectedMachine!.httpUrl).host;
//
//     return 'Add printer first';
//   }
//
//   Machine? get _selectedMachine =>
//       _selectedMachineService.selectedMachine.valueOrNull;
//
//   @override
//   Future<List<Machine>> futureToRun() => _machineService.fetchAll();
//
//   toggleManagePrintersExpanded() {
//     isManagePrintersExpanded = !isManagePrintersExpanded;
//     notifyListeners();
//   }
//
//   onEditTap(Machine? machine) {
//     machine ??= _selectedMachine;
//     if (machine == null) {
//       navigateTo(Routes.printerAdd);
//     } else {
//       navigateTo(Routes.printerEdit,
//           arguments: PrinterEditArguments(machine: machine));
//     }
//   }
//
//   onSetActiveTap(Machine machine) {
//     _navigationService.back();
//     _selectedMachineService.selectMachine(machine);
//   }
//

//
//   navigateMenu(String route, {dynamic arguments}) {
//     _navigationService.back();
//
//     if (currentPath != route)
//       _navigationService.clearStackAndShow(route, arguments: arguments);
//   }
//
//   navigateToLegal() {
//     _navigationService.navigateTo(Routes.imprintView);
//   }
//
//   bool isSelected(String route) => route == currentPath;
// }
