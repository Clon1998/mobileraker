/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/machine_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SwitchPrinterAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const SwitchPrinterAppBar({super.key, required this.title, required this.actions, this.bottom, this.centerTitle});

  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  final bool? centerTitle;

  @override
  ConsumerState createState() => _SwitchPrinterAppBarState();

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}

class _SwitchPrinterAppBarState extends ConsumerState<SwitchPrinterAppBar> {
  SelectedMachineService get _selectedMachineService => ref.read(selectedMachineServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  @override
  Widget build(BuildContext context) {
    final selectedMachine = ref.watch(selectedMachineProvider).valueOrNull;
    final multipleMachinesAvailable =
        ref.watch(allMachinesProvider.selectAs((data) => data.length > 1)).valueOrNull == true;

    return AppBar(
      centerTitle: widget.centerTitle ?? context.isLargerThanCompact,
      title: GestureDetector(
        onHorizontalDragEnd: onHorizontalDragEnd,
        onTap: multipleMachinesAvailable ? onTap : null,
        child: Text(
          selectedMachine?.name.let((it) => '$it - ${widget.title}') ?? widget.title,
          overflow: TextOverflow.fade,
        ),
      ),
      actions: widget.actions,
      bottom: widget.bottom,
    );
  }

  onTap() => _dialogService.show(DialogRequest(type: CommonDialogs.activeMachine));

  onHorizontalDragEnd(DragEndDetails endDetails) {
    final all = ref.read(allMachinesProvider.requireValue());
    final active = ref.read(selectedMachineProvider.requireValue());
    if (all.isEmpty || active == null) return;
    final activeIndex = all.indexOf(active);

    double primaryVelocity = endDetails.primaryVelocity ?? 0;
    if (primaryVelocity < 0) {
      // Next index
      final nextIndex = (activeIndex + 1) % all.length;
      _selectedMachineService.selectMachine(all[nextIndex]);
    } else if (primaryVelocity > 0) {
      // Previous index
      final previousIndex = (activeIndex - 1) % all.length;
      _selectedMachineService.selectMachine(all[previousIndex]);
    }
  }
}
