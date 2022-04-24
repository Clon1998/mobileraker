import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobileraker/ui/components/dialog/renameFile/rename_file_dialog_viewmodel.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class RenameFileDialogArguments {
  final String initialValue;
  final List<String> blocklist;
  final String? matchPattern;
  final String? fileExt;

  RenameFileDialogArguments(
      {required this.initialValue, this.blocklist = const [], this.matchPattern, this.fileExt});
}

class RenameFileDialogView
    extends ViewModelBuilderWidget<RenameFileDialogViewModel> {
  final DialogRequest request;
  final Function(DialogResponse) completer;

  const RenameFileDialogView(
      {Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget builder(
      BuildContext context, RenameFileDialogViewModel model, Widget? child) {
    return Dialog(
      child: FormBuilder(
        autovalidateMode: AutovalidateMode.always,
        key: model.formKey,
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
                  FormBuilderValidators.required(context),
                  FormBuilderValidators.match(context, model.pattern!),
                  notContains(context, model.blockList,
                      errorText: 'Name already in use!')
                ]),
                initialValue: model.initalValue,
                name: 'newValue',
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  border: const UnderlineInputBorder(),
                  contentPadding: const EdgeInsets.all(8.0),
                  labelText: request.description,
                  suffix: model.hasFileExt? Text(model.fileExt!):null
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: model.onFormDecline,
                    child: Text(request.secondaryButtonTitle!),
                  ),
                  TextButton(
                    onPressed: model.onFormConfirm,
                    child: Text(request.mainButtonTitle!),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  RenameFileDialogViewModel viewModelBuilder(BuildContext context) =>
      RenameFileDialogViewModel(request, completer);
}
