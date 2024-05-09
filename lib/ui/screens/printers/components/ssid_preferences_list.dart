/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/misc_providers.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../service/ui/dialog_service_impl.dart';
import '../../../components/dialog/text_input/text_input_dialog.dart';

part 'ssid_preferences_list.g.dart';

@riverpod
class SsidPreferenceListController extends _$SsidPreferenceListController {
  @override
  List<String> build(List<String> initValue) {
    return initValue;
  }

  Future<void> addSSID() async {
    await _openSSIDDialog(showHint: true);
  }

  Future<void> editSSID(String ssid) async {
    await _openSSIDDialog(showHint: true, initial: ssid);
  }

  deleteSSID(String ssid) {
    var current = [...state];
    current.remove(ssid);
    state = List.unmodifiable(current);
  }

  Future<void> _openSSIDDialog({String? initial, bool showHint = true}) async {
    var dialogResponse = await ref.read(dialogServiceProvider).show(
          DialogRequest(
            type: DialogType.textInput,
            title: tr(initial == null
                ? 'pages.printer_edit.local_ssid.dialog.title_add'
                : 'pages.printer_edit.local_ssid.dialog.title_edit'),
            actionLabel: tr(initial == null ? 'general.add' : 'general.save'),
            data: TextInputDialogArguments(
              initialValue: initial ?? '',
              labelText: tr('pages.printer_edit.local_ssid.dialog.label'),
              helperText: showHint ? tr('pages.printer_edit.local_ssid.dialog.quick_add_hint') : null,
              validator: FormBuilderValidators.required(),
            ),
          ),
        );

    if (dialogResponse?.confirmed == true) {
      if (state.contains(initial)) {
        List<String> tmp = [...state];
        var i = tmp.indexOf(initial!);
        tmp[i] = dialogResponse!.data as String;
        state = List.unmodifiable(tmp);
      } else {
        state = [...state, dialogResponse!.data as String];
      }
    }
  }

  Future<void> addCurrentSSID() async {
    var wifiName = await ref.read(networkInfoServiceProvider).getWifiName();
    if (state.contains(wifiName)) {
      await ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.warning,
            title: '$wifiName already in List',
          ));
      return;
    }

    if (wifiName?.isNotEmpty != true) {
      await ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.warning,
            title: tr(
              'pages.printer_edit.local_ssid.error_fetching_snackbar.title',
            ),
            message: tr(
              'pages.printer_edit.local_ssid.error_fetching_snackbar.body',
            ),
          ));
      return;
    }

    state = [...state, wifiName!];
  }
}

class SsidPreferenceList extends ConsumerWidget {
  const SsidPreferenceList({super.key, this.initialValue = const []});

  final List<String> initialValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = ssidPreferenceListControllerProvider(initialValue);
    var model = ref.watch(provider);
    var controller = ref.watch(provider.notifier);

    return InputDecorator(
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        helperText: tr('pages.printer_edit.local_ssid.helper'),
        helperMaxLines: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SectionHeader(
                title: tr('pages.printer_edit.local_ssid.section_header'),
              ),
              TextButton.icon(
                onPressed: controller.addSSID,
                onLongPress: controller.addCurrentSSID,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('general.add').tr(),
              ),
            ],
          ),
          if (model.isEmpty)
            Center(
              child: const Text('pages.printer_edit.local_ssid.no_ssids').tr(),
            ),
          ...model.map((e) => _SSID(
                value: e,
                onDelete: () => controller.deleteSSID(e),
                onTap: () => controller.editSSID(e),
              )),
        ],
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
    var themeData = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(children: [
              const Icon(Icons.wifi),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  style: themeData.listTileTheme.titleTextStyle,
                ),
              ),
            ]),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_forever),
          ),
        ],
      ),
    );
  }
}
