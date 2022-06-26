import 'package:flutter/widgets.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';
import 'package:stacked/stacked.dart';

mixin PrinterMixin on SelectedMachineMixin {
  @protected
  static const PrinterDataStreamKey = 'cPrinter';

  bool get isPrinterDataReady => dataReady(PrinterDataStreamKey);

  Printer get printerData => dataMap![PrinterDataStreamKey];

  @override
  Map<String, StreamData> get streamsMap {
    Map<String, StreamData> parentMap = super.streamsMap;
    return {
      ...parentMap,
      if (this.isSelectedMachineReady)
        PrinterDataStreamKey: StreamData<Printer>(printerService.printerStream),
    };
  }
}
