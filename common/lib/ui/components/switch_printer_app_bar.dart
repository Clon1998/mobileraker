/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/machine_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SwitchPrinterAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const SwitchPrinterAppBar({super.key, required this.title, required this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  ConsumerState createState() => _SwitchPrinterAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SwitchPrinterAppBarState extends ConsumerState<SwitchPrinterAppBar> {
  SelectedMachineService get _selectedMachineService => ref.read(selectedMachineServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  @override
  Widget build(BuildContext context) {
    var selectedMachine = ref.watch(selectedMachineProvider).valueOrNull;
    var multipleMachinesAvailable =
        ref.watch(allMachinesProvider.selectAs((data) => data.length > 1)).valueOrNull == true;
    return AppBar(
      centerTitle: false,
      title: GestureDetector(
        onHorizontalDragEnd: onHorizontalDragEnd,
        onTap: multipleMachinesAvailable ? onTap : null,
        child: Text(
          '${selectedMachine?.name ?? 'Printer'} - ${widget.title}',
          overflow: TextOverflow.fade,
        ),
      ),
      actions: widget.actions,
    );
  }

  onTap() => _dialogService.show(DialogRequest(type: CommonDialogs.activeMachine));

  onHorizontalDragEnd(DragEndDetails endDetails) {
    double primaryVelocity = endDetails.primaryVelocity ?? 0;
    if (primaryVelocity < 0) {
      // Page forwards
      _selectedMachineService.selectPreviousMachine();
    } else if (primaryVelocity > 0) {
      // Page backwards
      _selectedMachineService.selectNextMachine();
    }
  }
}
