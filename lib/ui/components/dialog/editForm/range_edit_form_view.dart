import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:get_utils/get_utils.dart';
import 'package:mobileraker/ui/components/dialog/editForm/num_edit_form_viewmodel.dart';
import 'package:stacked/stacked.dart';
import 'package:intl/intl.dart';
import 'package:stacked_services/stacked_services.dart';

class NumberEditDialogArguments {
  final num min;
  final num? max;
  final num current;
  final int fraction;

  NumberEditDialogArguments(
      {this.min = 0, this.max, required this.current, this.fraction = 0});
}

class RangeEditFormDialogView extends StatelessWidget {
  final DialogRequest request;
  final Function(DialogResponse) completer;

  const RangeEditFormDialogView(
      {Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    NumberEditDialogArguments data = request.data;

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
                FormBuilderSlider(
                  name: 'newValue',
                  initialValue:
                      data.current.toDouble().toPrecision(data.fraction),
                  min: data.min.toDouble(),
                  max: (data.max?? 100).toDouble(),
                  // divisions: (data.max + data.min.abs()).toInt(),
                  autofocus: true,
                  numberFormat: NumberFormat("####"),
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
