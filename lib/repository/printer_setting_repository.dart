import 'package:mobileraker/domain/machine.dart';

abstract class PrinterSettingRepository {
  Future<void> insert(Machine printerSetting);

  Future<void> update(Machine printerSetting);

  Future<Machine?> get({String? uuid, int index=-1});

  Future<Machine> remove(String uuid);

  Future<List<Machine>> fetchAll();
  Future<int> count();


}