/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'text_input_dialog.freezed.dart';

@freezed
class TextInputDialogArguments with _$TextInputDialogArguments {
  const factory TextInputDialogArguments({
    required String initialValue,
    FormFieldValidator<String>? validator,
    String? labelText,
    String? helperText,
    String? hintText,
    String? suffixText,
    ValueTransformer<String?>? valueTransformer,
  }) = _TextInputDialogArguments;
}

class TextInputDialog extends HookWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const TextInputDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context) {
    var formKey = useState(GlobalKey<FormBuilderState>());
    var isValid = useState(true);

    var dialogArgs = request.data as TextInputDialogArguments;

    return MobilerakerDialog(
      actionText: request.actionLabel ?? tr('general.confirm'),
      onAction: isValid.value
          ? () {
              if (formKey.value.currentState!.saveAndValidate()) {
                String formValue = formKey.value.currentState!.value['newValue'];
                completer(DialogResponse(confirmed: true, data: formValue));
              }
            }
          : null,
      dismissText: request.dismissLabel ?? tr('general.cancel'),
      onDismiss: () => completer(DialogResponse(confirmed: false)),
      child: FormBuilder(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        key: formKey.value,
        child: Column(
          mainAxisSize: MainAxisSize.min, // To make the card compact
          children: <Widget>[
            Text(
              request.title!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FormBuilderTextField(
              autofocus: true,
              validator: dialogArgs.validator,
              initialValue: dialogArgs.initialValue,
              name: 'newValue',
              keyboardType: TextInputType.text,
              valueTransformer: dialogArgs.valueTransformer,
              onChanged: (value) {
                isValid.value = formKey.value.currentState!.saveAndValidate();
              },
              decoration: InputDecoration(
                border: const UnderlineInputBorder(),
                contentPadding: const EdgeInsets.all(8.0),
                labelText: dialogArgs.labelText,
                suffixText: dialogArgs.suffixText,
                hintText: dialogArgs.hintText,
                helperText: dialogArgs.helperText,
                helperMaxLines: 5,
                errorMaxLines: 5,
                hintMaxLines: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
