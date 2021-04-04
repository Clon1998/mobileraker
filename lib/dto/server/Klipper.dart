import 'package:mobileraker/dto/machine/Printer.dart';

class KlipperInstance {

  bool klippyConnected = false;
  PrinterState klippyState = PrinterState.error;//Matches Printer state
  String get klippyStateName => printerStateName(klippyState);

  List<String> plugins = [];

  KlipperInstance({this.klippyConnected, this.klippyState, this.plugins});
}