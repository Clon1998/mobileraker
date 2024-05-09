/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../service/ui/dialog_service_impl.dart';

part 'macro_settings_dialog.g.dart';

class MacroSettingsDialog extends ConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const MacroSettingsDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        dialogCompleterProvider.overrideWithValue(completer),
      ],
      child: _MacroSettingsDialog(request: request, completer: completer),
    );
  }
}

class _MacroSettingsDialog extends ConsumerWidget {
  const _MacroSettingsDialog({super.key, required this.request, required this.completer});

  final DialogRequest request;
  final DialogCompleter completer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = _macroSettingsDialogControllerProvider(request, completer);

    var controller = ref.watch(provider.notifier);
    var model = ref.watch(provider);

    var themeData = Theme.of(context);
    return MobilerakerDialog(
      actionText: MaterialLocalizations.of(context).saveButtonLabel,
      onAction: controller.save,
      dismissText: MaterialLocalizations.of(context).cancelButtonLabel,
      onDismiss: controller.cancel,
      child: Column(
        mainAxisSize: MainAxisSize.min, // To make the card compact
        children: [
          Text(model.beautifiedName, style: themeData.textTheme.headlineSmall),
          Flexible(
            child: ListView(
              physics: const ClampingScrollPhysics(),
              shrinkWrap: true,
              children: [
                _Switch(
                  value: model.visible,
                  onChanged: controller.onVisibleChanged,
                  title: const Text('dialogs.macro_settings.visible').tr(),
                ),
                _Switch(
                  value: model.showWhilePrinting,
                  onChanged: controller.onShowWhilePrintingChanged,
                  title: const Text('dialogs.macro_settings.show_while_printing').tr(),
                ),
              ],
            ),
          ),
          const Divider(),

          // const _Footer()
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({super.key, required this.title, required this.value, this.onChanged});

  final Widget title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
      ),
      child: SwitchListTile(
        dense: true,
        isThreeLine: false,
        contentPadding: EdgeInsets.zero,
        title: title,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

@riverpod
class _MacroSettingsDialogController extends _$MacroSettingsDialogController {
  @override
  GCodeMacro build(DialogRequest request, DialogCompleter completer) {
    return request.data as GCodeMacro;
  }

  cancel() => completer(DialogResponse(confirmed: false));

  save() => completer(DialogResponse(confirmed: true, data: state));

  onVisibleChanged(bool value) {
    state = state.copyWith(visible: value);
  }

  onShowWhilePrintingChanged(bool value) {
    state = state.copyWith(showWhilePrinting: value);
  }
}
