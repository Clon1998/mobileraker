/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/dialog/select_printer/select_printer_controller.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';

class SelectPrinterDialog extends HookConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const SelectPrinterDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var selected = useState(false);

    if (selected.value) return const Center(child: CircularProgressIndicator.adaptive());

    var activeName = ref.watch(selectedMachineProvider.selectAs((data) => data?.name)).valueOrNull;
    var themeData = Theme.of(context);
    return MobilerakerDialog(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      paddingFooter: const EdgeInsets.all(8.0),
      dismissText: MaterialLocalizations.of(context).cancelButtonLabel,
      onDismiss: () {
        completer(DialogResponse.aborted());
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'dialogs.select_machine.title',
            style: themeData.textTheme.headlineSmall,
          ).tr(),
          Text(
            'dialogs.select_machine.active_machine',
            style: themeData.textTheme.bodyMedium,
          ).tr(args: [beautifyName(activeName ?? tr('general.unknown'))]),
          Flexible(
            child: Material(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: AsyncValueWidget<List<Machine>>(
                  value: ref.watch(selectPrinterDialogControllerProvider),
                  data: (d) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: d.length,
                    itemBuilder: (BuildContext context, int index) {
                      var machine = d[index];
                      return ListTile(
                        tileColor: themeData.colorScheme.surfaceVariant.withOpacity(.5),
                        textColor: themeData.colorScheme.onSurfaceVariant,
                        title: Text(beautifyName(machine.name)),
                        subtitle: Text(machine.httpUri.toString()),
                        onTap: () {
                          selected.value = true;
                          ref.read(selectPrinterDialogControllerProvider.notifier).selectMachine(machine);
                          completer(DialogResponse.confirmed());
                        },
                        trailing: MachineStateIndicator(machine),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Text(
            'dialogs.select_machine.hint',
            style: themeData.textTheme.bodySmall,
          ).tr(),
        ],
      ),
    );
  }
}
