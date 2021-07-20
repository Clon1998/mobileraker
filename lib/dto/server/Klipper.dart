import 'package:mobileraker/dto/machine/Printer.dart';

class KlipperInstance {
  bool klippyConnected;

  PrinterState klippyState; //Matches Printer state
  String get klippyStateName => printerStateName(klippyState);

  List<String> plugins;

  KlipperInstance(
      {this.klippyConnected = false,
      this.klippyState = PrinterState.error,
      this.plugins = const []});
}
