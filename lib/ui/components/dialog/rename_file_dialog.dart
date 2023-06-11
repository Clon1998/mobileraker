/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/util/misc.dart';

class RenameFileDialogArguments {
  final String initialValue;
  final List<String> blocklist;
  final String? matchPattern;

  RenameFileDialogArguments(
      {required this.initialValue,
      this.blocklist = const [],
      this.matchPattern});
}

class RenameFileDialog extends HookWidget {
  final DialogRequest request;
  final DialogCompleter completer;
  late final String? fileExt;
  late final String fileName;

  RenameFileDialog({Key? key, required this.request, required this.completer})
      : super(key: key) {
    RenameFileDialogArguments arg = request.data;
    var split = arg.initialValue.split(r'.');
    if (split.length > 1) {
      fileExt = '.${split.last}';
      split.removeLast();
      fileName = split.join('.');
    } else {
      fileExt = null;
      fileName = arg.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    var args = request.data as RenameFileDialogArguments;
    var formKey = useState(GlobalKey<FormBuilderState>());

    return Dialog(
      child: FormBuilder(
        autovalidateMode: AutovalidateMode.always,
        key: formKey.value,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // To make the card compact
            children: <Widget>[
              Text(
                request.title!,
                style: Theme.of(context).textTheme.headline5,
              ),
              FormBuilderTextField(
                autofocus: true,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  if (args.matchPattern != null)
                    FormBuilderValidators.match(args.matchPattern!),
                  notContains(context, args.blocklist,
                      errorText: 'Name already in use!')
                ]),
                initialValue: fileName,
                name: 'newValue',
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                    border: const UnderlineInputBorder(),
                    contentPadding: const EdgeInsets.all(8.0),
                    labelText: request.body,
                    suffix: fileExt != null ? Text(fileExt!) : null),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () =>
                        completer(DialogResponse(confirmed: false)),
                    child: Text(request.cancelBtn ?? tr('general.cancel')),
                  ),
                  TextButton(
                    onPressed: () {
                      if (formKey.value.currentState!.saveAndValidate()) {
                        String formValue =
                            formKey.value.currentState!.value['newValue'];
                        if (fileExt != null) formValue += fileExt!;
                        completer(
                            DialogResponse(confirmed: true, data: formValue));
                      }
                    },
                    child: Text(request.confirmBtn!),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
