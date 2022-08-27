import 'package:flutter/cupertino.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/util/extensions/double_extension.dart';

final initialFormType =
    Provider.autoDispose<DialogType>((ref) => throw UnimplementedError());

final numFraction =
    Provider.autoDispose<int>((ref) => throw UnimplementedError());

final dialogCompleter =
    Provider.autoDispose<DialogCompleter>(name: 'dialogCompleter', (ref) {
  throw UnimplementedError();
});

class NumberEditDialogArguments {
  final num min;
  final num? max;
  final num current;
  final int fraction;

  NumberEditDialogArguments(
      {this.min = 0, this.max, required this.current, this.fraction = 0});

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
    );
  }
}

final numEditFormKeyProvider =
    Provider.autoDispose<GlobalKey<FormBuilderState>>(
        (ref) => GlobalKey<FormBuilderState>());

final numEditFormDialogController =
    StateNotifierProvider.autoDispose<NumEditFormDialogController, DialogType>(
        (ref) => NumEditFormDialogController(ref));

class NumEditFormDialogController extends StateNotifier<DialogType> {
  NumEditFormDialogController(this.ref) : super(ref.read(initialFormType));

  final AutoDisposeRef ref;

  FormBuilderState get _formBuilderState =>
      ref.read(numEditFormKeyProvider).currentState!;

  onFormConfirm() {
    if (!_formBuilderState.saveAndValidate()) return;

    double val;
    if (state == DialogType.numEdit) {
      num cur = _formBuilderState.value['textValue'];
      val = cur.toDouble();
    } else {
      double cur = _formBuilderState.value['rangeValue'];
      val = cur;
    }
    ref.read(dialogCompleter)(DialogResponse(confirmed: true, data: val.toPrecision(ref.read(numFraction))));
  }

  onFormDecline() {
    ref.read(dialogCompleter)(DialogResponse.aborted());
  }

  switchToOtherVariant() {
    DialogType targetVariant;
    _formBuilderState.save();
    if (state == DialogType.numEdit) {
      targetVariant = DialogType.rangeEdit;

      num cur = _formBuilderState.value['textValue'];
      _formBuilderState.fields['rangeValue']!.didChange(cur.toDouble());
    } else {
      targetVariant = DialogType.numEdit;
      double cur = _formBuilderState.value['rangeValue'];
      _formBuilderState.fields['textValue']!
          .didChange(cur.toStringAsFixed(ref.read(numFraction)));
    }
    state = targetVariant;
  }
}
