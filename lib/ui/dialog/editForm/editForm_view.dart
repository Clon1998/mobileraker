import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'editForm_viewmodel.dart';

class FormDialogView extends StatelessWidget {
  const FormDialogView({Key? key, required this.request, required this.completer}) : super(key: key);

  final DialogRequest request;
  final Function(DialogResponse) completer;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<EditFormViewModel>.reactive(
      builder: (context, model, child) => Dialog(
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
                NumField(request: request),
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
      ),
      viewModelBuilder: () => EditFormViewModel(request, completer),
    );
  }
}

class NumField extends ViewModelWidget<EditFormViewModel> {
  const NumField({Key? key, required this.request}) : super(key: key);
  final DialogRequest request;

  @override
  Widget build(BuildContext context, EditFormViewModel model) {
    num currentValue = request.customData != null ? request.customData : 0;
    num lowerBorder = 0;
    num upperBorder = 300; //ToDo set to printers Max temp

    return FormBuilderTextField(
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.max(context,upperBorder),
        FormBuilderValidators.min(context,lowerBorder),
        FormBuilderValidators.numeric(context),
        FormBuilderValidators.required(context)
      ]),
      valueTransformer: (text) => num.tryParse(text),
      initialValue: currentValue.toStringAsFixed(0),
      name: 'newValue',
      style: Theme.of(context).inputDecorationTheme.counterStyle,
      keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
      decoration: InputDecoration(
          border: const UnderlineInputBorder(), contentPadding: EdgeInsets.all(12.0), labelText: request.description),
    );
  }
}
