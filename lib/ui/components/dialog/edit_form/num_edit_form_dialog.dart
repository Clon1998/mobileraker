/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geekyants_flutter_gauges/geekyants_flutter_gauges.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';

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
      logger.i('Controller changed: ${_controller.text}');
      setState(() {
        _validation = _validate(_controller.text);
        if (_isValid) {
          __value = num.tryParse(_controller.text) ?? 0;
        }
      });
      logger.i('Validation: $_validation');
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
          AnimatedCrossFade(
            duration: kThemeAnimationDuration,
            crossFadeState: DialogType.rangeEdit == _type ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: _RangeEditSlider(value: _value, args: widget.args, onChanged: _onSliderChanged),
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

class _RangeEditSlider extends HookWidget {
  const _RangeEditSlider({
    super.key,
    required this.value,
    required this.args,
    required this.onChanged,
  });

  final num value;
  final NumberEditDialogArguments args;
  final void Function(num) onChanged;

  @override
  Widget build(BuildContext context) {
    final lowerLimit = args.min.toDouble();
    final upperLimit = args.max?.toDouble() ?? 100.0;

    final numberFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: args.fraction);

    final themeData = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  onChanged(max(lowerLimit, value - 1));
                },
                onLongPress: () {
                  onChanged(lowerLimit);
                },
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Icon(Icons.remove),
                ),
              ),
              const Spacer(),
              Text(numberFormat.format(value)),
              const Spacer(),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  num t = value + 1;
                  if (t > (upperLimit)) {
                    t = upperLimit;
                  }
                  onChanged(t);
                },
                onLongPress: () {
                  onChanged(upperLimit);
                },
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
        LinearGauge(
          start: lowerLimit,
          end: upperLimit,
          customLabels: [
            CustomRulerLabel(text: numberFormat.format(lowerLimit), value: lowerLimit),
            CustomRulerLabel(text: numberFormat.format(upperLimit), value: upperLimit),
          ],
          valueBar: [
            ValueBar(
              enableAnimation: false,
              valueBarThickness: 6.0,
              value: value.toDouble(),
              color: themeData.colorScheme.primary,
              borderRadius: 5,
            ),
          ],
          pointers: [
            Pointer(
              value: value.toDouble(),
              shape: PointerShape.circle,
              color: themeData.colorScheme.primary,
              isInteractive: true,
              enableAnimation: false,
              height: 20,
              // width: 10,
              pointerAlignment: PointerAlignment.center,
              onChanged: onChanged,
            ),
          ],
          linearGaugeBoxDecoration: LinearGaugeBoxDecoration(
            thickness: 5,
            backgroundColor: themeData.colorScheme.primary.withOpacity(0.46),
            borderRadius: 5,
          ),
          rulers: RulerStyle(
            rulerPosition: RulerPosition.center,
            showPrimaryRulers: false,
            showSecondaryRulers: false,
            showLabel: true,
            labelOffset: 5,
            textStyle: themeData.textTheme.bodySmall,
          ),
        ),
      ],
    );
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
