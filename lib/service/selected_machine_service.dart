import 'package:hive/hive.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/repository/machine_hive_repository.dart';
import 'package:rxdart/rxdart.dart';

/// Service handling currently selected machine!
class SelectedMachineService {
  SelectedMachineService() : _boxUuid = Hive.box<String>('uuidbox') {
    String? selectedUUID = _boxUuid.get('selectedPrinter');
    if (selectedUUID != null)
      _machineRepo.get(uuid: selectedUUID).then((value) {
        if (value != null) selectMachine(value);
      });
  }

  final Box<String> _boxUuid;
  final BehaviorSubject<Machine?> selectedMachine = BehaviorSubject<Machine?>();

  final _logger = getLogger('SelectedMachineService');
  final _machineRepo = locator<MachineHiveRepository>();

  selectMachine(Machine? machine, [bool force = false]) async {
    _logger.i('Selecting machine $machine');
    if (machine == null) {
      // This case sets no printer as active!
      await _boxUuid.delete('selectedPrinter');
      if (!selectedMachine.isClosed) selectedMachine.add(null);

      _logger.i(
          "Selecting no printer as active Printer. Stream is closed?: ${selectedMachine.isClosed}");
      return;
    }

    if (!force && machine == selectedMachine.valueOrNull) return;

    await _boxUuid.put('selectedPrinter', machine.key);
    if (!selectedMachine.isClosed) {
      selectedMachine.add(machine);
    }
  }

  selectNextMachine() async {
    List<Machine> list = await _machineRepo.fetchAll();

    if (list.length < 2) return;
    _logger.i('Selecting next machine');
    int indexSelected = list.indexWhere(
        (element) => element.uuid == selectedMachine.valueOrNull?.uuid);
    int next = (indexSelected + 1) % list.length;
    selectMachine(list[next]);
  }

  selectPreviousMachine() async {
    List<Machine> list = await _machineRepo.fetchAll();
    if (list.length < 2) return;
    _logger.i('Selecting previous machine');
    int indexSelected = list.indexWhere(
        (element) => element.uuid == selectedMachine.valueOrNull?.uuid);
    int prev = (indexSelected - 1 < 0) ? list.length - 1 : indexSelected - 1;
    selectMachine(list[prev]);
  }

  bool isSelectedMachine(Machine toCheck) =>
      toCheck == selectedMachine.valueOrNull;

  dispose() {
    selectedMachine.close();
  }
}
