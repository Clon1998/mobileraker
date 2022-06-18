import 'package:flutter/widgets.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/ui/common/mixins/machine_multi_stream_view_model.dart';
import 'package:stacked/stacked.dart';

mixin PrinterMultiStreamViewModel on MachineMultiStreamViewModel {
  @protected
  static const PrinterDataStreamKey = 'cPrinter';

  bool get isPrinterDataReady => dataReady(PrinterDataStreamKey);

  Printer get printerData => dataMap![PrinterDataStreamKey];

  @override
  Map<String, StreamData> get streamsMap {
    Map<String, StreamData> parentMap = super.streamsMap;
    return {
      ...parentMap,
      if (this.isMachineAvailable)
        PrinterDataStreamKey: StreamData<Printer>(printerService.printerStream),
    };
  }
}
