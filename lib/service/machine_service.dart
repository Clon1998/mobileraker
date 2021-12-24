import 'dart:async';

import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:hive/hive.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/service/database_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

class MachineService {
  final _logger = getLogger('MachineService');

  // NotificationService notificationService = locator<NotificationService>();
  late final _boxPrinterSettings = Hive.box<PrinterSetting>('printers');
  late final _boxUuid = Hive.box<String>('uuidbox');

  late final BehaviorSubject<PrinterSetting?> selectedMachine;
  StreamSubscription<FGBGType>? _fgbgStreamSub;

  Stream<BoxEvent> get printerSettingEventStream => _boxPrinterSettings.watch();

  MachineService() {
    String? selectedUUID = _boxUuid.get('selectedPrinter');
    var fromBox = _boxPrinterSettings.get(selectedUUID);
    selectedMachine = BehaviorSubject<PrinterSetting?>();

    if (selectedUUID != null && fromBox != null) setMachineActive(fromBox);

    _fgbgStreamSub = FGBGEvents.stream.listen((event) {
      if (event == FGBGType.foreground)
        selectedMachine.valueOrNull?.websocket.ensureConnection();
    });
  }

  Future<void> updateMachine(PrinterSetting printerSetting) async {
    await printerSetting.save();
    if (!selectedMachine.isClosed && isSelectedMachine(printerSetting))
      selectedMachine.add(printerSetting);
    return;
  }

  Future<PrinterSetting> addMachine(PrinterSetting printerSetting) async {
    await _boxPrinterSettings.put(printerSetting.uuid, printerSetting);
    await setMachineActive(printerSetting);
    return printerSetting;
  }

  Future<void> removeMachine(PrinterSetting printerSetting) async {
    await printerSetting.delete();
    if (_boxUuid.get('selectedPrinter') == printerSetting.uuid) {
      var key = (_boxPrinterSettings.isEmpty)
          ? null
          : _boxPrinterSettings.values.first;

      await setMachineActive(key);
    }
  }

  Iterable<PrinterSetting> fetchAll() {
    return _boxPrinterSettings.values;
  }

  setMachineActive(PrinterSetting? printerSetting) async {
    if (printerSetting == selectedMachine.valueOrNull) return;
    // This case will be called when no printer is left! -> Select no printer as active printer
    if (printerSetting == null) {
      await _boxUuid.delete('selectedPrinter');
      if (!selectedMachine.isClosed) selectedMachine.add(null);
      return;
    }

    await _boxUuid.put('selectedPrinter', printerSetting.key);
    if (!selectedMachine.isClosed) selectedMachine.add(printerSetting);
  }

  selectNextMachine() {
    List<PrinterSetting> list = fetchAll().toList();

    if (list.length < 2) return;
    _logger.i('Selecting next machine');
    int indexSelected = list.indexWhere(
        (element) => element.uuid == selectedMachine.valueOrNull?.uuid);
    int next = (indexSelected + 1) % list.length;
    setMachineActive(list[next]);
  }

  selectPreviousMachine() {
    List<PrinterSetting> list = fetchAll().toList();
    if (list.length < 2) return;
    _logger.i('Selecting previous machine');
    int indexSelected = list.indexWhere(
        (element) => element.uuid == selectedMachine.valueOrNull?.uuid);
    int prev = (indexSelected - 1 < 0) ? list.length - 1 : indexSelected - 1;
    setMachineActive(list[prev]);
  }

  bool machineAvailable() {
    return selectedMachine.valueOrNull != null;
  }

  bool isSelectedMachine(PrinterSetting toCheck) =>
      toCheck == selectedMachine.valueOrNull;

  Future<String> fetchOrCreateFcmIdentifier(
      PrinterSetting printerSetting) async {
    DatabaseService databaseService = printerSetting.databaseService;

    String? item =
        await databaseService.getDatabaseItem('mobileraker', 'printerId');
    if (item == null) {
      String nId = Uuid().v4();
      _logger.i("Creating fcm-PrinterId in moonraker-Database: $nId");
      item = await databaseService.addDatabaseItem(
          'mobileraker', 'printerId', nId);
    }
    _logger.i(
        "Setting fcm-PrinterId from moonraker-Database in PrinterSettings = $item");

    printerSetting.fcmIdentifier = item;
    await printerSetting.save();
    return item!;
  }

  PrinterSetting? machineFromFcmIdentifier(String fcmIdentifier) {
    for (PrinterSetting element in fetchAll())
      if (element.fcmIdentifier == fcmIdentifier) return element;
    return null;
  }

  int indexOfMachine(PrinterSetting setting) {
    int i = -1;
    for (PrinterSetting element in fetchAll()) {
      i++;
      if (element == setting) return i;
    }
    return i;
  }

  dispose() {
    selectedMachine.close();
    _fgbgStreamSub?.cancel();
    for (PrinterSetting machine in fetchAll()) {
      machine.disposeServices();
    }
  }
}
