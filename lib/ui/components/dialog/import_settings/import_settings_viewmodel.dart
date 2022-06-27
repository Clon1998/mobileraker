import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/temperature_preset.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/ui/components/dialog/import_settings/import_settings_view.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ImportMachineSettingsDto {
  ImportMachineSettingsDto(this.machine, this.machineSettings);

  final Machine machine;
  final MachineSettings machineSettings;
}

class ImportSettingsViewModel extends FutureViewModel<List<ImportMachineSettingsDto>> {
  final _machineService = locator<MachineService>();
  final DialogRequest request;
  final Function(DialogResponse) completer;

  final _fbKey = GlobalKey<FormBuilderState>();
  late final Machine _target;
  ImportMachineSettingsDto? _selectedSource;

  Key get formKey => _fbKey;

  bool get machineSelected => _selectedSource != null;

  ImportSettingsViewModel(this.request, this.completer) {
    _target = request.data;
  }


  @override
  Future<List<ImportMachineSettingsDto>> futureToRun() async {
    Iterable<Machine> machines = (await _machineService.fetchAll()).where((element) => element != _target);
    Iterable<Future<ImportMachineSettingsDto?>> map = machines.map((e) async {
      try {
        MachineSettings machineSettings = await _machineService.fetchSettings(e).timeout(Duration(seconds: 2));
        return ImportMachineSettingsDto(e, machineSettings);
      } catch (e) {
        return null;
      }
    });
    List<ImportMachineSettingsDto?> rawList = await Future.wait(map);
    return rawList.whereType<ImportMachineSettingsDto>().toList(growable: false);
  }



  List<TemperaturePreset> get presets {
    return _selectedSource?.machineSettings.temperaturePresets ?? List.empty();
  }

  onSourceSelected(ImportMachineSettingsDto? machineAndSettings) {
    if (machineAndSettings != _selectedSource) {
      _selectedSource = machineAndSettings;
      notifyListeners();
    }
  }

  onFormConfirm() {
    FormBuilderState currentState = _fbKey.currentState!;
    if (currentState.saveAndValidate()) {
      List<TemperaturePreset> selectedPresets =
          currentState.value['temp_presets'] ?? [];

      List<String> fields = [];
      fields.addAll(currentState.value['motionsysFields'] ?? []);
      fields.addAll(currentState.value['extrudersFields'] ?? []);

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
