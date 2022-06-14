import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/data/dto/machine/exclude_object.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker/machine_settings.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ExcludeObjectViewModel extends StreamViewModel<Printer> {
  final DialogRequest request;

  final Function(DialogResponse) completer;

  final _selectedMachineService = locator<SelectedMachineService>();

  final _fbKey = GlobalKey<FormBuilderState>();

  GlobalKey<FormBuilderState> get formKey => _fbKey;

  Machine? _machine;

  ParsedObject? selectedObject;

  Printer get printer => data!;

  PrinterService? get _printerService => _machine?.printerService;

  ExcludeObject get excludeObject {
    return printer.excludeObject;
  }

  ExcludeObjectViewModel(this.request, this.completer);

  @override
  void initialise() {
    _machine = _selectedMachineService.selectedMachine.valueOrNull;
    super.initialise();
  }

  @override
  Stream<Printer> get stream => _printerService!.printerStream;

  void onPathTapped(ParsedObject obj) {
    _fbKey.currentState?.fields['selected']!.didChange(obj);
  }

  void onSelectedObjectChanged(ParsedObject? obj) {
    if (selectedObject == obj)
      selectedObject = null;
    else
      selectedObject = obj;
  }

  onCancelPressed() {
    completer(DialogResponse(confirmed: false));
  }
}
