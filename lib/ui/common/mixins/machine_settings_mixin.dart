import 'package:flutter/material.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/data/model/moonraker/machine_settings.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';
import 'package:stacked/stacked.dart';

mixin MachineSettingsMixin on SelectedMachineMixin {
  @protected
  static const StreamKey = 'machSettings';
  final _machineService = locator<MachineService>();

  bool get isMachineSettingsReady => dataReady(StreamKey);

  MachineSettings get machineSettings => dataMap![StreamKey];

  @override
  Map<String, StreamData> get streamsMap {
    Map<String, StreamData> parentMap = super.streamsMap;

    return {
      ...parentMap,
      if (this.isSelectedMachineReady)
        StreamKey: StreamData<MachineSettings>(
            _machineService.fetchSettings(selectedMachine!).asStream()),
    };
  }
}
