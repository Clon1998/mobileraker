import 'package:hive_flutter/hive_flutter.dart';
import 'package:listenable_stream/listenable_stream.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class PrintersViewModel extends StreamViewModel<Box<PrinterSetting>> {
  final _navigationService = locator<NavigationService>();

  var printers = Hive.box<PrinterSetting>('printers');

  Iterable<PrinterSetting> fetchSettings() {
    if (dataReady) {
      var list = data!.values.toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } else
      return Iterable.empty();
  }

  @override
  Stream<Box<PrinterSetting>> get stream => Hive.box<PrinterSetting>('printers')
      .listenable()
      .toValueStream(replayValue: true);

  onAddPrinterPressed() {
    _navigationService.navigateTo(Routes.printersAdd);
  }
}
