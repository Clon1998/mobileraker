import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobileraker/ui/components/dialog/editForm/range_edit_form_view.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import 'num_edit_form_viewmodel.dart';

class NumEditFormDialogView extends StatelessWidget {
  final DialogRequest request;
  final Function(DialogResponse) completer;

  const NumEditFormDialogView(
      {Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    NumberEditDialogArguments data = request.data;

    return ViewModelBuilder<NumEditFormViewModel>.reactive(
      builder: (context, model, child) {
        var themeData = Theme.of(context);
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
                    style: themeData.textTheme.titleLarge,
                  ),
                  _NumField(
                    description: request.description,
                    initialValue: data.current,
                    upperBorder: data.max,
                    lowerBorder: data.min,
                    frac: data.fraction,
                  ),
                  NumberDialogFooter(
                    canSwitch: data.canSwitch,
                  )
                ],
              ),
            ),
          ),
        );
      },
      viewModelBuilder: () => NumEditFormViewModel(request, completer),
    );
  }
}

class _NumField extends StatelessWidget {
  final num initialValue;
  final num lowerBorder;
  final num? upperBorder;
  final int frac;
  final String? description;

  const _NumField(
      {Key? key,
      required this.initialValue,
      required this.lowerBorder,
      this.upperBorder,
      required this.frac,
      this.description})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormBuilderTextField(
      autofocus: true,
      validator: FormBuilderValidators.compose([
        if (upperBorder != null) FormBuilderValidators.max(upperBorder!),
        FormBuilderValidators.min(lowerBorder),
        FormBuilderValidators.numeric(),
        if (frac == 0) FormBuilderValidators.integer(),
        FormBuilderValidators.required()
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
    if (upperBorder == null) return 'Enter a value of at least $lowerBorder';

    return 'Enter a value between $lowerBorder and $upperBorder';
  }
}
