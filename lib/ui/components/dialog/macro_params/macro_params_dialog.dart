/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stringr/stringr.dart';

final macroParamsFormKeyProvider =
    Provider.autoDispose<GlobalKey<FormBuilderState>>(
  (ref) => GlobalKey<FormBuilderState>(),
);

final dialogCompleter =
    Provider.autoDispose<DialogCompleter>((ref) => throw UnimplementedError());

final macroProvider =
    Provider.autoDispose<ConfigGcodeMacro>(name: 'macroProvider', (ref) {
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

    return Dialog(
      child: FormBuilder(
        autovalidateMode: AutovalidateMode.always,
        key: ref.watch(macroParamsFormKeyProvider),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // To make the card compact
            children: [
              Text(
                '${macro.macroName.capitalize()}-Params',
                style: Theme.of(context).textTheme.headlineSmall,
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
              const Divider(),
              Text(
                'dialogs.gcode_params.hint',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ).tr(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () =>
                        ref.read(dialogCompleter)(DialogResponse.aborted()),
                    child: const Text('general.cancel').tr(),
                  ),
                  TextButton(
                    onPressed: () => _submit(ref),
                    child: const Text('general.confirm').tr(),
                  ),
                ],
              ),
              // const _Footer()
            ],
          ),
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
