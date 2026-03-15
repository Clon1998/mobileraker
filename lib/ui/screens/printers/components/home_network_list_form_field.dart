/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/misc_providers.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';

import '../../../../service/ui/dialog_service_impl.dart';
import '../../../components/dialog/text_input/text_input_dialog.dart';

class HomeNetworkListFormField extends ConsumerWidget {
  const HomeNetworkListFormField({super.key, required this.name, this.initialValue = const []});

  final String name;
  final List<String> initialValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkInfo = ref.read(networkInfoServiceProvider);
    final snackBarService = ref.read(snackBarServiceProvider);
    final dialogService = ref.read(dialogServiceProvider);

    return InputDecorator(
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        helperText: tr('pages.printer_edit.local_ssid.helper'),
        helperMaxLines: 10,
      ),
      child: FormBuilderField(
        name: name,
        initialValue: initialValue,
        builder: (field) {
          final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled?? true);
          final ssids = field.value ?? [];

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SectionHeader(title: tr('pages.printer_edit.local_ssid.section_header')),
                  TextButton.icon(
                    onPressed: (() => showDialog(dialogService).then((dialogResponse) {
                      if (dialogResponse case DialogResponse(confirmed: true, data: final String newSSID)) {
                        field.didChange(List.unmodifiable([...ssids, newSSID]));
                      }
                    })).only(enabled),
                    onLongPress:( () => networkInfo.getWifiName().then((wifiName) {
                      if (!field.mounted) return;
                      if (wifiName?.isNotEmpty != true) {
                        snackBarService.show(
                          SnackBarConfig(
                            type: SnackbarType.warning,
                            title: tr('pages.printer_edit.local_ssid.error_fetching_snackbar.title'),
                            message: tr('pages.printer_edit.local_ssid.error_fetching_snackbar.body'),
                          ),
                        );
                      } else {
                        field.didChange(List.unmodifiable([...ssids, wifiName!]));
                      }
                    })).only(enabled),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('general.add').tr(),
                  ),
                ],
              ),
              if (ssids.isEmpty) Center(child: const Text('pages.printer_edit.local_ssid.no_ssids').tr()),
              for (var ssid in ssids)
                _SSID(
                  value: ssid,
                  onDelete: (() => field.didChange(List.unmodifiable([...ssids]..remove(ssid)))).only(enabled),
                  onTap: (() => showDialog(dialogService, ssid).then((dialogResponse) {
                    if (dialogResponse case DialogResponse(confirmed: true, data: final String updatedSSID)) {
                      final updated = [...ssids];
                      final index = updated.indexOf(ssid);
                      updated[index] = updatedSSID;
                      field.didChange(List.unmodifiable(updated));
                    }
                  })).only(enabled),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<DialogResponse?> showDialog(DialogService dialogService, [String? initial]) {
    return dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        title: tr(
          initial == null
              ? 'pages.printer_edit.local_ssid.dialog.title_add'
              : 'pages.printer_edit.local_ssid.dialog.title_edit',
        ),
        actionLabel: tr(initial == null ? 'general.add' : 'general.save'),
        data: TextInputDialogArguments(
          initialValue: initial ?? '',
          labelText: tr('pages.printer_edit.local_ssid.dialog.label'),
          helperText: tr('pages.printer_edit.local_ssid.dialog.quick_add_hint'),
          validator: FormBuilderValidators.required(),
        ),
      ),
    );
  }
}

class _SSID extends StatelessWidget {
  const _SSID({super.key, required this.value, this.onTap, this.onDelete});

  final String value;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              spacing: 8,
              children: [
                const Icon(Icons.wifi),
                Flexible(child: Text(value, style: themeData.listTileTheme.titleTextStyle)),
              ],
            ),
          ),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_forever)),
        ],
      ),
    );
  }
}
