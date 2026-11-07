/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/machine_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SwitchPrinterAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const SwitchPrinterAppBar({
    super.key,
    required this.title,
    required this.actions,
    this.bottom,
    this.centerTitle,
    this.status,
  });

  final String title;

  /// Shown after the page title in the subtitle, e.g. the machine's connection/print state.
  final Widget? status;
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
    final selectedMachine = ref.watch(selectedMachineProvider).value;
    final multipleMachinesAvailable =
        ref.watch(allMachinesProvider.selectAs((data) => data.length > 1)).value == true;

    final centerTitle = widget.centerTitle ?? context.isLargerThanCompact;
    final textTheme = Theme.of(context).textTheme;

    return AppBar(
      centerTitle: centerTitle,
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: onHorizontalDragEnd,
        onTap: multipleMachinesAvailable ? onTap : null,
        child: selectedMachine == null
            ? Text(widget.title, overflow: TextOverflow.fade)
            // The Builder picks up the AppBar's title style so themes with colored app bars keep their foreground
            : Builder(
                builder: (context) {
                  final base = DefaultTextStyle.of(context).style;
                  final titleStyle = base.copyWith(
                    fontSize: textTheme.titleMedium?.fontSize,
                    height: textTheme.titleMedium?.height,
                  );
                  final subtitleStyle = base.copyWith(
                    fontSize: textTheme.bodySmall?.fontSize,
                    height: textTheme.bodySmall?.height,
                    letterSpacing: textTheme.bodySmall?.letterSpacing,
                    fontWeight: textTheme.bodySmall?.fontWeight,
                    color: base.color?.withValues(alpha: 0.75),
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedMachine.name,
                        style: titleStyle,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                      DefaultTextStyle.merge(
                        style: subtitleStyle,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(widget.title, maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
                            ),
                            if (widget.status case final status?) ...[const Text(' · '), Flexible(child: status)],
                          ],
                        ),
                      ),
                    ],
                  );
                },
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
