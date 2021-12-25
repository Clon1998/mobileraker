import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/domain/temperature_preset.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/ui/dialog/importSettings/import_settings_view.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ImportSettingsViewModel extends BaseViewModel {
  final _machineService = locator<MachineService>();
  final DialogRequest request;
  final Function(DialogResponse) completer;

  final _fbKey = GlobalKey<FormBuilderState>();
  late final PrinterSetting _target;
  PrinterSetting? _selectedSource;

  Key get formKey => _fbKey;

  bool get machineSelected => _selectedSource != null;

  ImportSettingsViewModel(this.request, this.completer) {
    _target = request.data;
  }

  Iterable<PrinterSetting> get machines =>
      _machineService.fetchAll().where((element) => element != _target);

  List<TemperaturePreset> get presets {
    return _selectedSource?.temperaturePresets ?? List.empty();
  }

  void onSourceSelected(PrinterSetting? printerSetting) {
    if (printerSetting != _selectedSource) {
      _selectedSource = printerSetting;
      notifyListeners();
    }
  }

  onFormConfirm() {
    FormBuilderState currentState = _fbKey.currentState!;
    if (currentState.saveAndValidate()) {
      List<TemperaturePreset> selectedPresets =
          currentState.value['temp_presets']?? [];

      List<String> fields = [];
      fields.addAll(currentState.value['motionsysFields']??[]);
      fields.addAll(currentState.value['extrudersFields']??[]);

      completer(DialogResponse(
          confirmed: true,
          data: ImportSettingsDialogViewResults(
              source: _selectedSource!,
              presets: selectedPresets,
              fields: fields)));
    }
  }

  onFormDecline() {
    completer(DialogResponse(confirmed: false));
  }
}
