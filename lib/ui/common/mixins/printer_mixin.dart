import 'package:flutter/widgets.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';
import 'package:stacked/stacked.dart';

mixin PrinterMixin on SelectedMachineMixin {
  @protected
  static const StreamKey = 'cPrinter';

  bool get isPrinterDataReady => dataReady(StreamKey);

  Printer get printerData => dataMap![StreamKey];

  bool get isPrinting =>
      isPrinterDataReady && printerData.print.state == PrintState.printing;

  bool get isNotPrinting => isPrinterDataReady && !isPrinting;

  bool get isPaused =>
      isPrinterDataReady && printerData.print.state == PrintState.paused;

  bool get isNotPaused => isPrinterDataReady && !isPaused;

  bool get isPrintingOrPaused => isPrinterDataReady && (isPrinting || isPaused);

  bool get isNotPrintingOrPaused => isPrinterDataReady && !isPrintingOrPaused;

  @override
  Map<String, StreamData> get streamsMap {
    Map<String, StreamData> parentMap = super.streamsMap;
    return {
      ...parentMap,
      if (this.isSelectedMachineReady)
        StreamKey: StreamData<Printer>(printerService.printerStream),
    };
  }
}
