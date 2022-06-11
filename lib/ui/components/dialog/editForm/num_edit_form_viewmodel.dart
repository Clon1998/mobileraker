import 'package:flutter/cupertino.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:get/get.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/ui/components/dialog/setup_dialog_ui.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class NumberEditDialogArguments {
  final num min;
  final num? max;
  final num current;
  final int fraction;
  final bool canSwitch;

  NumberEditDialogArguments(
      {this.min = 0,
      this.max,
      required this.current,
      this.fraction = 0,
      this.canSwitch = true});

  NumberEditDialogArguments copyWith(
      {num? min,
      num? max = double.nan,
      num? current,
      int? fraction,
      bool? canSwitch}) {
    return NumberEditDialogArguments(
      current: current ?? this.current,
      min: min ?? this.min,
      max: (max?.isNaN ?? false) ? this.max : max,
      fraction: fraction ?? this.fraction,
      canSwitch: canSwitch ?? this.canSwitch,
    );
  }
}

class NumEditFormViewModel extends BaseViewModel {
  NumEditFormViewModel(this.request, this.completer);

  final _logger = getLogger('NumEditFormViewModel');
  final _dialogService = locator<DialogService>();
  final DialogRequest request;
  final Function(DialogResponse) completer;
  final _editFormKey = GlobalKey<FormBuilderState>();

  Key get formKey => _editFormKey;

  onFormConfirm() {
    if (_editFormKey.currentState!.saveAndValidate()) {
      _logger.i('Form Completed');
      completer(DialogResponse(
          confirmed: true, data: _editFormKey.currentState!.value['newValue']));
    }
  }

  onFormDecline() {
    completer(DialogResponse(confirmed: false));
    _logger.i('Form Declined');
  }

  switchToOtherVariant() async {
    dynamic targetVariant = DialogType.numEditForm;
    if (request.variant == DialogType.numEditForm)
      targetVariant = DialogType.rangeEditForm;

    NumberEditDialogArguments dialogArgs = request.data;
    num? curData = fetchCurrentInput();

    DialogResponse? otherResp = await _dialogService.showCustomDialog(
        variant: targetVariant,
        title: request.title,
        mainButtonTitle: request.mainButtonTitle,
        secondaryButtonTitle: request.secondaryButtonTitle,
        data: dialogArgs.copyWith(canSwitch: false, current: curData));

    if (otherResp != null) {
      if (otherResp.confirmed) completer(otherResp);
      if (otherResp.data != null) {
        num changed = otherResp.data;

        if (request.variant == DialogType.numEditForm)
          _editFormKey.currentState!.fields['newValue']
              ?.didChange(changed.toStringAsFixed(dialogArgs.fraction));
        if (request.variant == DialogType.rangeEditForm)
          _editFormKey.currentState!.fields['newValue']
              ?.didChange(changed.toDouble().toPrecision(dialogArgs.fraction));
      } else {
        onFormDecline();
      }
    }
  }

  switchBack() {
    completer(DialogResponse(confirmed: false, data: fetchCurrentInput()));
  }

  num? fetchCurrentInput() {
    num? curData;
    if (_editFormKey.currentState!.saveAndValidate()) {
      curData = _editFormKey.currentState!.value['newValue'];
    }
    return curData;
  }
}
