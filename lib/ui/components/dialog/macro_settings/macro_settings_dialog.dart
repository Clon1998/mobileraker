/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/extensions/object_extension.dart';
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
                _WrapStates(
                  inputDecoration: InputDecoration(
                    labelText: 'dialogs.macro_settings.show_for_states'.tr(),
                    labelStyle: themeData.textTheme.bodyLarge,
                    helperText: 'dialogs.macro_settings.show_for_states_hint'.tr(),
                    helperMaxLines: 10,
                  ),
                  active: model.showForState,
                  onChanged: controller.onShowForStateChanged,
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

class _WrapStates extends StatelessWidget {
  const _WrapStates({super.key, required this.inputDecoration, required this.active, required this.onChanged});

  final InputDecoration inputDecoration;
  final Set<PrintState> active;
  final void Function(PrintState, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return InputDecorator(
      decoration: inputDecoration,
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        children: [
          for (var state in PrintState.values)
            FilterChip(
              selected: active.contains(state),
              avatar: const Icon(Icons.circle_outlined).unless(active.contains(state)),
              iconTheme: IconThemeData(color: themeData.disabledColor),
              checkmarkColor: themeData.colorScheme.primary,
              elevation: 2,
              label: Text(state.displayName),
              onSelected: (bool s) => onChanged(state, s),
            ),
        ],
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

  void cancel() => completer(DialogResponse(confirmed: false));

  void save() => completer(DialogResponse(confirmed: true, data: state));

  void onVisibleChanged(bool value) {
    state = state.copyWith(visible: value);
  }

  void onShowForStateChanged(PrintState printState, bool selected) {
    if (selected) {
      state = state.copyWith(showForState: {...state.showForState, printState});
    } else {
      state = state.copyWith(showForState: {...state.showForState}..remove(printState));
    }
  }
}
