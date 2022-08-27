import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/data/model/moonraker_db/temperature_preset.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';

final importTarget = Provider.autoDispose<Machine>(name: 'importTarget', (ref) {
  throw UnimplementedError();
});

final dialogCompleter =
    Provider.autoDispose<DialogCompleter>(name: 'dialogCompleter', (ref) {
  throw UnimplementedError();
});

final importSettingsFormKeyProvider =
    Provider.autoDispose<GlobalKey<FormBuilderState>>(
        (ref) => GlobalKey<FormBuilderState>());

final footerControllerProvider = StateProvider.autoDispose((ref) => false);

final importSources =
    FutureProvider.autoDispose<List<ImportMachineSettingsDto>>((ref) async {
  List<Machine> machines = await ref.watch(allMachinesProvider.future);

  Machine target = ref.watch(importTarget);

  Iterable<Future<ImportMachineSettingsDto?>> map =
      machines.where((element) => element.uuid != target.uuid).map((e) async {
    try {
      MachineSettings machineSettings = await ref
          .watch(machineServiceProvider)
          .fetchSettings(e)
          .timeout(const Duration(seconds: 2));
      return ImportMachineSettingsDto(e, machineSettings);
    } catch (e) {
      logger.w('Error while trying to fetch settings!',e);
      return null;
    }
  });
  List<ImportMachineSettingsDto?> rawList = await Future.wait(map);


  var list = rawList.whereType<ImportMachineSettingsDto>().toList(growable: false);
  if (list.isEmpty) {
    return Future.error('No sources for import found!');
  }
  return list;
});

final importSettingsDialogController = StateNotifierProvider.autoDispose<
        ImportSettingsDialogController, AsyncValue<ImportMachineSettingsDto>>(
    (ref) => ImportSettingsDialogController(ref));

class ImportSettingsDialogController
    extends StateNotifier<AsyncValue<ImportMachineSettingsDto>> {
  ImportSettingsDialogController(this.ref) : super(const AsyncValue.loading()) {
    ref.listen(importSources,
        (previous, AsyncValue<List<ImportMachineSettingsDto>> next) {
      next.when(
          data: (sources) {
            state = AsyncValue.data(sources.first);
          },
          error: (e, s) => state = AsyncValue.error(e, stackTrace: s),
          loading: () => null);
    },fireImmediately: true);
  }

  final AutoDisposeRef ref;

  onSourceChanged(ImportMachineSettingsDto? selected) {
    state = AsyncValue.data(selected!);
  }

  onFormConfirm() {
    FormBuilderState currentState =
        ref.read(importSettingsFormKeyProvider).currentState!;
    if (currentState.saveAndValidate()) {
      List<TemperaturePreset> selectedPresets =
          currentState.value['temp_presets'] ?? [];

      List<String> fields = [];
      fields.addAll(currentState.value['motionsysFields'] ?? []);
      fields.addAll(currentState.value['extrudersFields'] ?? []);

      ref.read(dialogCompleter)(DialogResponse(
          confirmed: true,
          data: ImportSettingsDialogViewResults(
              source: state.value!, presets: selectedPresets, fields: fields)));
    }
  }
}

class ImportSettingsDialogViewResults {
  final ImportMachineSettingsDto source;
  final List<TemperaturePreset> presets;
  final List<String> fields;

  ImportSettingsDialogViewResults(
      {required this.source, required this.presets, required this.fields});
}

class ImportMachineSettingsDto {
  ImportMachineSettingsDto(this.machine, this.machineSettings);

  final Machine machine;
  final MachineSettings machineSettings;
}
