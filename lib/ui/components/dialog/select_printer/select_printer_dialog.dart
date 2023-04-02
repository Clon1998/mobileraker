import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/dialog/select_printer/select_printer_controller.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/misc.dart';

class SelectPrinterDialog extends HookConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const SelectPrinterDialog(
      {Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var selected = useState(false);

    if (selected.value) return const Center(child: CircularProgressIndicator());

    var activeName = ref
        .watch(selectedMachineProvider.selectAs((data) => data?.name))
        .valueOrFullNull;
    var themeData = Theme.of(context);
    return Dialog(
        child: Padding(
      padding: const EdgeInsets.only(top: 15.0),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: AsyncValueWidget<List<Machine>>(
              value: ref.watch(selectPrinterDialogControllerProvider),
              data: (d) => ListView.builder(
                shrinkWrap: true,
                itemCount: d.length,
                itemBuilder: (BuildContext context, int index) {
                  var machine = d[index];
                  return ListTile(
                    tileColor:
                        themeData.colorScheme.surfaceVariant.withOpacity(.5),
                    textColor: themeData.colorScheme.onSurfaceVariant,
                    title: Text(beautifyName(machine.name)),
                    onTap: () {
                      selected.value = true;
                      ref
                          .read(selectPrinterDialogControllerProvider.notifier)
                          .selectMachine(machine);
                      completer(DialogResponse.confirmed());
                    },
                    trailing: MachineStateIndicator(machine),
                  );
                },
              ),
            ),
          ),
          Text(
            'dialogs.select_machine.hint',
            style: themeData.textTheme.bodySmall,
          ).tr(),
          _Footer(dialogCompleter: completer)
        ],
      ),
    ));
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({Key? key, required this.dialogCompleter}) : super(key: key);
  final DialogCompleter dialogCompleter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      // mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () {
            dialogCompleter(DialogResponse.aborted());
          },
          child: const Text('general.cancel').tr(),
        )
      ],
    );
  }
}
