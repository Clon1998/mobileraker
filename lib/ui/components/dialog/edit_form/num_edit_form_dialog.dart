/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';

import '../../range_edit_slider.dart';

part 'num_edit_form_dialog.freezed.dart';

class NumEditFormDialog extends ConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const NumEditFormDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(request.data is NumberEditDialogArguments, 'Data must be of type NumberEditDialogArguments');

    return _NumberEditDialog(completer: completer, request: request);
  }
}

class _NumberEditDialog extends ConsumerStatefulWidget {
  const _NumberEditDialog({super.key, required this.request, required this.completer});

  final DialogRequest request;
  final DialogCompleter completer;

  NumberEditDialogArguments get args => request.data as NumberEditDialogArguments;

  @override
  ConsumerState createState() => _NumberEditDialogState();
}

class _NumberEditDialogState extends ConsumerState<_NumberEditDialog> {
  final TextEditingController _controller = TextEditingController();

  String? _validation;
  DialogIdentifierMixin _type = DialogType.numEdit;

  num __value = 0;

  bool get _isValid => _validation == null;

  num get _value => __value;

  set _value(num value) {
    __value = value;
    _controller.text = value.toStringAsFixed(widget.args.fraction);
  }

  @override
  void initState() {
    super.initState();

    _type = widget.request.type;
    _value = widget.request.data!.current;

    _controller.addListener(() {
      // logger.i('Controller changed: ${_controller.text}');
      setState(() {
        _validation = _validate(_controller.text);
        if (_isValid) {
          __value = num.tryParse(_controller.text) ?? 0;
        }
      });
      // logger.i('Validation: $_validation');
      // setState(() {
      //   if (_isValid) {
      //     _value = num.tryParse(_controller.text) ?? 0;
      //   }
      // });
    });
  }

  @override
  void didUpdateWidget(_NumberEditDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    _type = widget.request.type;
    _value = widget.request.data!.current;
  }

  void onFormConfirm() {
    if (_isValid) {
      widget.completer(DialogResponse.confirmed(_value));
    }
  }

  void onFormDecline() => widget.completer(DialogResponse.aborted());

  void toggleVariant() {
    setState(() {
      _type = _type == DialogType.rangeEdit ? DialogType.numEdit : DialogType.rangeEdit;
    });
  }

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);

    return MobilerakerDialog(
      footer: Row(
        // mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: onFormDecline,
            child: Text(widget.request.dismissLabel ?? tr('general.cancel')),
          ),
          IconButton(
            onPressed: toggleVariant.only(_isValid),
            color: _isValid ? themeData.textTheme.bodySmall?.color : themeData.disabledColor,
            iconSize: 18,
            icon: AnimatedSwitcher(
              duration: kThemeAnimationDuration,
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Icon(_type == DialogType.rangeEdit ? Icons.text_fields : Icons.straighten),
            ),
          ),
          TextButton(
            onPressed: onFormConfirm.only(_isValid),
            child: Text(
              widget.request.actionLabel ?? tr('general.confirm'),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // To make the card compact
        children: <Widget>[
          Text(widget.request.title!, style: themeData.textTheme.titleLarge),
          if (widget.request.body != null) Text(widget.request.body!, style: themeData.textTheme.bodySmall),
          AnimatedCrossFade(
            duration: kThemeAnimationDuration,
            crossFadeState: DialogType.rangeEdit == _type ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: RangeEditSlider(
              value: _value,
              lowerLimit: widget.args.min,
              upperLimit: widget.args.max ?? 100,
              decimalPlaces: widget.args.fraction,
              onChanged: _onSliderChanged,
            ),
            secondChild: _NumField(controller: _controller, args: widget.args, errorText: _validation),
          ),
        ],
      ),
    );
  }

  void _onSliderChanged(num newValue) {
    setState(() {
      _value = newValue;
    });
  }

  String? _validate(String value) {
    var validator = FormBuilderValidators.compose([
      FormBuilderValidators.min(widget.args.min),
      if (widget.args.max != null) FormBuilderValidators.max(widget.args.max!),
      FormBuilderValidators.numeric(),
      if (widget.args.fraction == 0) FormBuilderValidators.integer(),
      FormBuilderValidators.required(),
    ]);

    return validator(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _NumField extends StatelessWidget {
  const _NumField({super.key, required this.args, required this.controller, this.errorText});

  final NumberEditDialogArguments args;
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
      decoration: InputDecoration(
        border: const UnderlineInputBorder(),
        contentPadding: const EdgeInsets.all(8.0),
        // labelText: description,
        errorText: errorText,
        helperText: _helperText(),
      ),
    );
  }

  String _helperText() {
    if (args.max == null) return 'Enter a value of at least ${args.min}';

    return 'Enter a value between ${args.min} and ${args.max}';
  }
}

@freezed
class NumberEditDialogArguments with _$NumberEditDialogArguments {
  const factory NumberEditDialogArguments({
    @Default(0) num min,
    num? max,
    required num current,
    @Default(0) int fraction,
  }) = _NumberEditDialogArguments;
}
