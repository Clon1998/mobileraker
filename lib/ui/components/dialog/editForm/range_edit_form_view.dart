import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:intl/intl.dart';
import 'package:mobileraker/ui/components/dialog/editForm/num_edit_form_viewmodel.dart';
import 'package:mobileraker/ui/components/dialog/setup_dialog_ui.dart';
import 'package:mobileraker/util/extensions/double_extension.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

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
                  FormBuilderSlider(
                    name: 'newValue',
                    initialValue:
                        data.current.toDouble().toPrecision(data.fraction),
                    min: data.min.toDouble(),
                    max: (data.max ?? 100).toDouble(),
                    // divisions: (data.max + data.min.abs()).toInt(),
                    autofocus: true,
                    numberFormat: NumberFormat(data.fraction == 0
                        ? "####"
                        : "0." + List.filled(data.fraction, '0').join()),
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

class NumberDialogFooter extends ViewModelWidget<NumEditFormViewModel> {
  const NumberDialogFooter({Key? key, required this.canSwitch})
      : super(key: key);

  final bool canSwitch;

  @override
  Widget build(BuildContext context, NumEditFormViewModel model) {
    ThemeData themeData = Theme.of(context);

    var captionStyle = themeData.textTheme.caption;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: model.onFormDecline,
          child: Text(model.request.secondaryButtonTitle!),
        ),
        if (canSwitch)
          IconButton(
            onPressed: model.switchToOtherVariant,
            icon: Icon(
              model.request.variant == DialogType.rangeEditForm
                  ? Icons.text_fields
                  : Icons.straighten,
              color: captionStyle?.color,
              size: 18,
            ),
          ),
        if (!canSwitch)
          TextButton(
              onPressed: model.switchBack,
              child: Text(
                MaterialLocalizations.of(context).backButtonTooltip,
                style: captionStyle,
              )),
        TextButton(
          onPressed: model.onFormConfirm,
          child: Text(model.request.mainButtonTitle!),
        )
      ],
    );
  }
}
