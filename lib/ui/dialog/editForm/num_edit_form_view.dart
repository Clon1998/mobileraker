import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'num_edit_form_viewmodel.dart';

class NumEditFormDialogViewArguments {
  final num? min;
  final num? max;
  final num? current;
  final int? fraction;

  NumEditFormDialogViewArguments(
      {this.min, this.max, this.current, this.fraction});
}

class NumEditFormDialogView extends StatelessWidget {
  final DialogRequest request;
  final Function(DialogResponse) completer;

  const NumEditFormDialogView(
      {Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    NumEditFormDialogViewArguments data = request.data;

    return ViewModelBuilder<NumEditFormViewModel>.reactive(
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
                NumField(
                  description: request.description,
                  initialValue: data.current ?? 0,
                  upperBorder: data.max,
                  lowerBorder: data.min ?? 0,
                  frac: data.fraction ?? 0,
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
      ),
      viewModelBuilder: () => NumEditFormViewModel(request, completer),
    );
  }
}

class NumField extends StatelessWidget {
  final num initialValue;
  final num lowerBorder;
  final num? upperBorder;
  final int frac;
  final String? description;

  const NumField(
      {Key? key,
      this.initialValue = 0,
      this.lowerBorder = 0,
      this.upperBorder = 100,
      this.frac = 0,
      this.description})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormBuilderTextField(
      autofocus: true,
      validator: FormBuilderValidators.compose([
        if (upperBorder != null)
          FormBuilderValidators.max(context, upperBorder!),
        FormBuilderValidators.min(context, lowerBorder),
        FormBuilderValidators.numeric(context),
        FormBuilderValidators.required(context)
      ]),
      valueTransformer: (String? text) => text == null ? 0 : num.tryParse(text),
      initialValue: initialValue.toStringAsFixed(frac),
      name: 'newValue',
      style: Theme.of(context).inputDecorationTheme.counterStyle,
      keyboardType:
          TextInputType.numberWithOptions(signed: false, decimal: false),
      decoration: InputDecoration(
        border: const UnderlineInputBorder(),
        contentPadding: const EdgeInsets.all(8.0),
        labelText: description,
        helperText: _helperText(),
      ),
    );
  }
  String _helperText() {
    if (upperBorder == null)
      return 'Enter a value of at least $lowerBorder';

    return 'Enter a value between $lowerBorder and $upperBorder';
  }
}
