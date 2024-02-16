/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'select_printer_controller.g.dart';

@riverpod
class SelectPrinterDialogController extends _$SelectPrinterDialogController {
  @override
  FutureOr<List<Machine>> build() async {
    var active = await ref.watch(selectedMachineProvider.selectAsync((data) => data?.uuid));

    if (active == null) {
      return ref.watch(allMachinesProvider.future);
    }

    return ref.watch(allMachinesProvider
        .selectAsync((data) => data.where((element) => element.uuid != active).toList(growable: false)));
  }

  selectMachine(Machine machine) {
    ref.read(selectedMachineServiceProvider).selectMachine(machine);
  }
}
