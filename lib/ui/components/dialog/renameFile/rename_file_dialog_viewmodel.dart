import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/ui/components/dialog/renameFile/rename_file_dialog_view.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class RenameFileDialogViewModel extends BaseViewModel {
  RenameFileDialogViewModel(this.request, this.completer);

  final DialogRequest request;
  final Function(DialogResponse) completer;
  final _editFormKey = GlobalKey<FormBuilderState>();

  Key get formKey => _editFormKey;

  RenameFileDialogArguments get _arguments => request.data;

  String get initalValue {
    if (hasFileExt) {
      assert(_arguments.initialValue.endsWith(fileExt!),
          'File does not end with expected File Extension!');
      var split = _arguments.initialValue.split('.');
      split.removeLast();
      return split.join('.');
    }
    return _arguments.initialValue;
  }

  List<String> get blockList => _arguments.blocklist;

  String? get pattern => _arguments.matchPattern;

  bool get hasFileExt => _arguments.fileExt != null;

  String? get fileExt => '.${_arguments.fileExt}';

  onFormConfirm() {
    if (_editFormKey.currentState!.saveAndValidate()) {
      String formValue = _editFormKey.currentState!.value['newValue'];
      if (hasFileExt) formValue += fileExt!;
      completer(DialogResponse(confirmed: true, data: formValue));
    }
  }

  onFormDecline() {
    completer(DialogResponse(confirmed: false));
  }
}
