import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:rxdart/rxdart.dart';

class SelectedMachineService {
  late final _boxPrinterSettings = Hive.box<PrinterSetting>('printers');
  late final _boxUuid = Hive.box<String>('uuidbox');

  // Todo: Close this stream
  late final BehaviorSubject<PrinterSetting?> selectedPrinter;

  SelectedMachineService() {
    String? selectedUUID = _boxUuid.get('selectedPrinter');
    var fromBox = _boxPrinterSettings.get(selectedUUID);
    if (selectedUUID != null && fromBox != null) {
      selectedPrinter = BehaviorSubject<PrinterSetting?>.seeded(fromBox);
    } else
      selectedPrinter = BehaviorSubject<PrinterSetting?>();
  }

  setPrinterActive(PrinterSetting? printerSetting) async {
    if (printerSetting == selectedPrinter.valueOrNull)
      return;
    if (printerSetting == null) {
      await _boxUuid.delete('selectedPrinter');
      selectedPrinter.add(null);
      return;
    }

    await _boxUuid.put('selectedPrinter', printerSetting.key);
    selectedPrinter.add(printerSetting);
  }

  bool printerAvailable() {
    return selectedPrinter.valueOrNull != null;
  }

  bool isSelectedMachine(PrinterSetting toCheck) => toCheck == selectedPrinter.valueOrNull;

  dispose() {
    selectedPrinter.close();
  }
}
