import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/change_notifier.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/service/PrinterSettingsService.dart';
import 'package:stacked/stacked.dart';
import 'package:listenable_stream/listenable_stream.dart';
import 'package:stacked_services/stacked_services.dart';

class PrintersViewModel extends StreamViewModel<Box<PrinterSetting>> {
  final _navigationService = locator<NavigationService>();

  var printers = Hive.box<PrinterSetting>('printers');

  Iterable<PrinterSetting> fetchSettings() {
    if (data == null)
      return Iterable.empty();
    else
      return data!.values;
  }

  @override
  Stream<Box<PrinterSetting>> get stream => Hive.box<PrinterSetting>('printers')
      .listenable()
      .toValueStream(replayValue: true);

  onAddPrinterPressed() {
    _navigationService.navigateTo(Routes.printersAdd);
  }
}
