import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/data/dto/machine/exclude_object.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
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

  bool get formValid => _fbKey.currentState?.isValid == true;

  Machine? _machine;

  ParsedObject? selectedObject;

  bool confirmed = false;

  Printer get printer => data!;

  PrinterService? get _printerService => _machine?.printerService;

  ExcludeObject get excludeObject {
    return printer.excludeObject;
  }

  double get maxX => printer.configFile.stepperX?.positionMax ?? 300;

  double get minX => printer.configFile.stepperX?.positionMin ?? 0;

  double get maxY => printer.configFile.stepperY?.positionMax ?? 300;

  double get minY => printer.configFile.stepperY?.positionMin ?? 0;

  double get sizeX => maxX + minX.abs();

  double get sizeY => maxY + minY.abs();

  bool get canExclude =>
      excludeObject.objects.length - excludeObject.excludedObjects.length > 1;

  ExcludeObjectViewModel(this.request, this.completer);

  @override
  void initialise() {
    _machine = _selectedMachineService.selectedMachine.valueOrNull;
    super.initialise();
  }

  @override
  Stream<Printer> get stream => _printerService!.printerStream;

  @override
  void onData(Printer? data) {
    if (data == null) return;
    // Close form if print finished!
    if (data.print.state != PrintState.printing) closeForm();
  }

  void onPathTapped(ParsedObject obj) {
    if (confirmed) return;
    _fbKey.currentState?.fields['selected']!.didChange(obj);
  }

  void onSelectedObjectChanged(ParsedObject? obj) {
    if (selectedObject == obj)
      return;
    else
      selectedObject = obj;
    notifyListeners();
  }

  onExcludePressed() {
    if (_fbKey.currentState?.saveAndValidate() == false) return;

    if (confirmed) {
    } else {
      confirmed = true;
      notifyListeners();
    }
  }

  onCofirmPressed() {
    if (selectedObject != null && canExclude)
      _printerService?.excludeObject(selectedObject!);

    closeForm();
  }

  onBackPressed() {
    confirmed = false;
    notifyListeners();
  }

  closeForm() => completer(DialogResponse(confirmed: false));
}
