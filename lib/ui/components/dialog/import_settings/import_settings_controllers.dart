/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/data/model/moonraker_db/settings/temperature_preset.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final importTarget = Provider.autoDispose<Machine>(name: 'importTarget', (ref) {
  throw UnimplementedError();
});

final dialogCompleter = Provider.autoDispose<DialogCompleter>(name: 'dialogCompleter', (ref) {
  throw UnimplementedError();
});

final importSettingsFormKeyProvider = Provider.autoDispose<GlobalKey<FormBuilderState>>(
  (ref) => GlobalKey<FormBuilderState>(),
);

final importSources = FutureProvider.autoDispose<List<ImportMachineSettingsResult>>((ref) async {
  List<Machine> machines = await ref.watch(allMachinesProvider.future);

  Machine target = ref.watch(importTarget);

  Iterable<Future<ImportMachineSettingsResult?>> map =
      machines.where((element) => element.uuid != target.uuid).map((e) async {
    try {
      var connected = await ref
          .watchWhere(
            jrpcClientStateProvider(e.uuid),
            (c) => c == ClientState.connected || c == ClientState.error,
          )
          .then((value) => value == ClientState.connected)
          .timeout(const Duration(seconds: 10));

      if (!connected) {
        logger.w(
          'Could not fetch settings, no JRPC connection for ${e.logNameExtended}',
        );
        return null;
      }

      MachineSettings machineSettings = await ref.watch(machineServiceProvider).fetchSettings(machine: e);
      return ImportMachineSettingsResult(e, machineSettings);
    } catch (er) {
      logger.w('Error while trying to fetch settings for ${e.logNameExtended} !', er);
      return null;
    }
  });
  List<ImportMachineSettingsResult?> rawList = await Future.wait(map);

  var list = rawList.whereType<ImportMachineSettingsResult>().toList(growable: false);
  if (list.isEmpty) {
    return Future.error('No sources for import found!');
  }
  return list;
});

final importSettingsDialogController = StateNotifierProvider.autoDispose<ImportSettingsDialogController, AsyncValue<ImportMachineSettingsResult>>(
  (ref) => ImportSettingsDialogController(ref),
);

class ImportSettingsDialogController
    extends StateNotifier<AsyncValue<ImportMachineSettingsResult>> {
  ImportSettingsDialogController(this.ref) : super(const AsyncValue.loading()) {
    ref.listen(
      importSources,
      (previous, AsyncValue<List<ImportMachineSettingsResult>> next) {
        next.when(
          data: (sources) {
            state = AsyncValue.data(sources.first);
          },
          error: (e, s) => state = AsyncValue.error(e, s),
          loading: () => null,
        );
      },
      fireImmediately: true,
    );
  }

  final AutoDisposeRef ref;

  onSourceChanged(ImportMachineSettingsResult? selected) {
    state = AsyncValue.data(selected!);
  }

  onFormConfirm() {
    FormBuilderState currentState = ref.read(importSettingsFormKeyProvider).currentState!;
    if (currentState.saveAndValidate()) {
      List<TemperaturePreset> selectedPresets = currentState.value['temp_presets'] ?? [];

      List<String> fields = [];
      fields.addAll(currentState.value['motionsysFields'] ?? []);
      fields.addAll(currentState.value['extrudersFields'] ?? []);

      ref.read(dialogCompleter)(DialogResponse(
        confirmed: true,
        data: ImportSettingsDialogViewResults(
          source: state.value!,
          presets: selectedPresets,
          fields: fields,
        ),
      ));
    }
  }
}

class ImportSettingsDialogViewResults {
  final ImportMachineSettingsResult source;
  final List<TemperaturePreset> presets;
  final List<String> fields;

  const ImportSettingsDialogViewResults({
    required this.source,
    required this.presets,
    required this.fields,
  });
}

class ImportMachineSettingsResult {
  const ImportMachineSettingsResult(this.machine, this.machineSettings);

  final Machine machine;
  final MachineSettings machineSettings;
}
