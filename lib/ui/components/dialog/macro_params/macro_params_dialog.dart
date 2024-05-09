/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stringr/stringr.dart';

final macroParamsFormKeyProvider = Provider.autoDispose<GlobalKey<FormBuilderState>>(
  (ref) => GlobalKey<FormBuilderState>(),
);

final dialogCompleter = Provider.autoDispose<DialogCompleter>((ref) => throw UnimplementedError());

final macroProvider = Provider.autoDispose<ConfigGcodeMacro>(name: 'macroProvider', (ref) {
  throw UnimplementedError();
});

class MacroParamsDialog extends ConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const MacroParamsDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        dialogCompleter.overrideWithValue(completer),
        macroProvider.overrideWithValue(request.data as ConfigGcodeMacro),
      ],
      child: const _MacroParamsDialog(),
    );
  }
}

class _MacroParamsDialog extends ConsumerWidget {
  const _MacroParamsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ConfigGcodeMacro macro = ref.watch(macroProvider);
    var paramNames = macro.params.keys.toList(growable: false);

    var themeData = Theme.of(context);
    return MobilerakerDialog(
      actionText: tr('general.confirm'),
      onAction: () => _submit(ref),
      dismissText: MaterialLocalizations.of(context).cancelButtonLabel,
      onDismiss: () => ref.read(dialogCompleter)(DialogResponse.aborted()),
      child: FormBuilder(
        autovalidateMode: AutovalidateMode.always,
        key: ref.watch(macroParamsFormKeyProvider),
        child: Column(
          mainAxisSize: MainAxisSize.min, // To make the card compact
          children: [
            if (paramNames.isNotEmpty)
              _ParamsDialog(macro: macro, paramNames: paramNames)
            else
              _ConfirmDialog(macro: macro),
            const Divider(),
            Text(
              'dialogs.gcode_params.hint',
              textAlign: TextAlign.center,
              style: themeData.textTheme.bodySmall,
            ).tr(),

            // const _Footer()
          ],
        ),
      ),
    );
  }

  _submit(WidgetRef ref) {
    var formKey = ref.read(macroParamsFormKeyProvider).currentState!;

    formKey.saveAndValidate();

    var paramsValuesMap = formKey.value.cast<String, String>();
    ref.read(dialogCompleter)(DialogResponse.confirmed(paramsValuesMap));
  }
}

class _ParamsDialog extends StatelessWidget {
  const _ParamsDialog({super.key, required this.macro, required this.paramNames});

  final ConfigGcodeMacro macro;
  final List<String> paramNames;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${macro.macroName.capitalize()}-Params',
          style: themeData.textTheme.headlineSmall,
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: paramNames.length,
            itemBuilder: (context, index) {
              var paramName = paramNames[index];
              var paramDefault = macro.params[paramName];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: FormBuilderTextField(
                  name: paramName,
                  initialValue: paramDefault,
                  decoration: InputDecoration(
                    border: const UnderlineInputBorder(),
                    contentPadding: const EdgeInsets.all(8.0),
                    labelText: paramName,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({super.key, required this.macro});

  final ConfigGcodeMacro macro;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'dialogs.gcode_params.confirm_title',
          style: themeData.textTheme.headlineSmall,
        ).tr(args: [macro.macroName.capitalize()]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'dialogs.gcode_params.confirm_body',
            textAlign: TextAlign.start,
            style: themeData.textTheme.labelLarge,
          ).tr(args: [macro.macroName.capitalize()]),
        ),
      ],
    );
  }
}
