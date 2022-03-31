import 'package:flutter/cupertino.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class NumEditFormViewModel extends BaseViewModel {
  NumEditFormViewModel(this.request, this.completer);

  final DialogRequest request;
  final Function(DialogResponse) completer;
  final _editFormKey = GlobalKey<FormBuilderState>();
  Key get formKey => _editFormKey;

  onFormConfirm() {
    if (_editFormKey.currentState!.saveAndValidate()) {
      completer(DialogResponse(confirmed: true, data:  _editFormKey.currentState!.value['newValue']));
    }
  }

  onFormDecline() {
      completer(DialogResponse(confirmed: false));
  }
}