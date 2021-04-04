import 'package:flutter/cupertino.dart';
import 'package:flutter_form_builder_fixed/flutter_form_builder.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class EditFormViewModel extends BaseViewModel {
  EditFormViewModel(this.request, this.completer);

  final DialogRequest request;
  final Function(DialogResponse) completer;
  final _fbKey = GlobalKey<FormBuilderState>();
  Key get formKey => _fbKey;

  onFormConfirm() {
    if (_fbKey.currentState.saveAndValidate()) {
      completer(DialogResponse(confirmed: true, responseData:  _fbKey.currentState.value['newValue']));
    }
  }

  onFormDecline() {
      completer(DialogResponse(confirmed: false));
  }
}