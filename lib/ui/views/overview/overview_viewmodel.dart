import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _MachineList = 'machineList';

class OverViewViewModel extends MultipleStreamViewModel {
  final _logger = getLogger('MasterViewModel');
  final _machineService = locator<MachineService>();
  final _navigationService = locator<NavigationService>();

  List<PrinterSetting> get machines => dataMap![_MachineList];

  bool get areMachinesAvailable => dataReady(_MachineList);

  void onAddPressed() {
    _navigationService.navigateTo(Routes.printersAdd);
  }

  @override
  Map<String, StreamData> get streamsMap => {
        _MachineList: StreamData<List<PrinterSetting>>(
            _machineService.fetchAll().asStream())
      };
}
