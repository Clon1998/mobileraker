import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/domain/machine.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class OverViewViewModel extends FutureViewModel<List<Machine>> {
  final _machineService = locator<MachineService>();
  final _navigationService = locator<NavigationService>();

  @override
  Future<List<Machine>> futureToRun() => _machineService.fetchAll();

  onAddPressed() {
    _navigationService.navigateTo(Routes.printersAdd);
  }
}
