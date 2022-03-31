import 'package:mobileraker/domain/printer_setting.dart';

abstract class PrinterSettingRepository {
  Future<void> insert(PrinterSetting printerSetting);

  Future<void> update(PrinterSetting printerSetting);

  Future<PrinterSetting?> get({String? uuid, int index=-1});

  Future<PrinterSetting> remove(String uuid);

  Future<List<PrinterSetting>> fetchAll();
  Future<int> count();


}