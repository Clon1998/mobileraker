import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'editForm_viewmodel.dart';

class EditFormDialogViewArguments {
  final num? min;
  final num? max;
  final num? current;
  final int? fraction;

  EditFormDialogViewArguments({this.min, this.max, this.current, this.fraction});
}

class EditFormDialogView extends StatelessWidget {
  final DialogRequest request;
  final Function(DialogResponse) completer;

  const EditFormDialogView(
      {Key? key, required this.request, required this.completer})
      : super(key: key);

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
    EditFormDialogViewArguments passedData = request.data;
    num currentValue = passedData.current ?? 0;
    num lowerBorder = passedData.min ?? 0;
    num upperBorder = passedData.max ?? 100;
    int frac = passedData.fraction ?? 0;

    return FormBuilderTextField(
      autofocus: true,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.max(context, upperBorder),
        FormBuilderValidators.min(context, lowerBorder),
        FormBuilderValidators.numeric(context),
        FormBuilderValidators.required(context)
      ]),
      valueTransformer: (String? text) => text == null ? 0 : num.tryParse(text),
      initialValue: currentValue.toStringAsFixed(frac.toInt()),
      name: 'newValue',
      style: Theme.of(context).inputDecorationTheme.counterStyle,
      keyboardType:
          TextInputType.numberWithOptions(signed: false, decimal: false),
      decoration: InputDecoration(
        border: const UnderlineInputBorder(),
        contentPadding: EdgeInsets.all(8.0),
        labelText: request.description,
        helperText: "Enter a value between $lowerBorder and $upperBorder",
      ),
    );
  }
}
